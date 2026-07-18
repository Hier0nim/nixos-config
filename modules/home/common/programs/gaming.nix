{
  pkgs,
  inputs,
  ...
}:
let
  gamewrapAuto = pkgs.writeTextFile {
    name = "gamewrap-auto";
    executable = true;
    destination = "/bin/gamewrap-auto";
    text =
      # py
      ''
        #!${pkgs.python3}/bin/python3
        from __future__ import annotations

        import json
        import os
        import subprocess
        import sys
        from dataclasses import dataclass

        GAMESCOPE = "${pkgs.gamescope}/bin/gamescope"
        GAMEMODERUN = "${pkgs.gamemode}/bin/gamemoderun"
        NIRI = "${pkgs.niri}/bin/niri"

        def env_flag(name: str, default: str = "0") -> bool:
            return os.environ.get(name, default) == "1"

        DEBUG = env_flag("GAMEWRAP_DEBUG")
        DRYRUN = env_flag("GAMEWRAP_DRYRUN")

        def log(msg: str) -> None:
            if DEBUG:
                print(f"gamewrap-auto: {msg}", file=sys.stderr)

        @dataclass(frozen=True)
        class Mode:
            width: int
            height: int
            hz: float

            @property
            def hz_rounded(self) -> int:
                return int(round(self.hz))

        @dataclass(frozen=True)
        class OutputInfo:
            name: str
            adaptive_sync_support: bool
            current_mode: Mode

            @property
            def is_internal_panel(self) -> bool:
                return self.name.startswith("eDP-")

        def niri_json(*args: str) -> dict:
            p = subprocess.run(
                [NIRI, "msg", "-j", *args],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=2,
            )
            if p.returncode != 0:
                if p.stderr:
                    log(p.stderr.strip())
                raise SystemExit(f"gamewrap-auto: niri msg {' '.join(args)} failed")
            return json.loads(p.stdout)

        def parse_output(data: dict) -> OutputInfo:
            name = data.get("name")
            modes = data.get("modes")
            current_mode = data.get("current_mode")

            if not isinstance(name, str) or not name:
                raise SystemExit("gamewrap-auto: niri output has no name")
            if not isinstance(modes, list) or not modes:
                raise SystemExit(f"gamewrap-auto: niri output {name} has no modes")
            if not isinstance(current_mode, int) or current_mode < 0 or current_mode >= len(modes):
                raise SystemExit(f"gamewrap-auto: niri output {name} has invalid current_mode")

            mode = modes[current_mode]
            width = mode.get("width")
            height = mode.get("height")
            refresh = mode.get("refresh_rate")

            if not all(isinstance(v, int) and v > 0 for v in (width, height)) or not (
                isinstance(refresh, (int, float)) and refresh > 0
            ):
                raise SystemExit(f"gamewrap-auto: niri output {name} has invalid mode data")

            return OutputInfo(
                name=name,
                adaptive_sync_support=bool(data.get("vrr_supported")),
                current_mode=Mode(
                    width=width,
                    height=height,
                    hz=refresh / 1000.0,
                ),
            )

        def choose_output() -> OutputInfo:
            try:
                out = parse_output(niri_json("focused-output"))
                log(f"Picked {out.name} because it's the focused output")
                return out
            except Exception as e:
                log(f"focused-output unavailable: {e}")

            outputs = niri_json("outputs")
            if not isinstance(outputs, dict) or not outputs:
                raise SystemExit("gamewrap-auto: no enabled niri outputs found")

            first = next(iter(outputs.values()))
            out = parse_output(first)
            log(f"Picked {out.name} because it's the first niri output")
            return out

        def build_gamescope_args(out: OutputInfo) -> tuple[list[str], dict[str, str]]:
            m = out.current_mode

            args: list[str] = [
                "-f",
                "--force-grab-cursor",
                "-W", str(m.width),
                "-H", str(m.height),
                "--mangoapp",
            ]

            if out.adaptive_sync_support:
                args += ["--adaptive-sync"]
            else:
                args += ["-r", str(m.hz_rounded)]

            env_add: dict[str, str] = {}

            # HDR policy: internal panel only
            if out.is_internal_panel:
                args += ["--hdr-enabled", "--hdr-itm-enabled"]
                env_add["ENABLE_HDR_WSI"] = "1"
                env_add["DXVK_HDR"] = "1"
                if env_flag("GAMEWRAP_FORCE_HDR"):
                    args += ["--hdr-debug-force-output"]

            return args, env_add

        def main(argv: list[str]) -> int:
            if len(argv) < 2:
                print("Usage: gamewrap-auto <command> [args...]", file=sys.stderr)
                return 2

            chosen = choose_output()
            gs_args, env_add = build_gamescope_args(chosen)
            env = os.environ.copy()
            env.update(env_add)

            original_ld_preload = env.get("LD_PRELOAD", "")
            env["LD_PRELOAD"] = ""

            inner = [GAMEMODERUN] + argv[1:]
            if original_ld_preload:
                inner = ["env", f"LD_PRELOAD={original_ld_preload}", *inner]

            full_cmd = [GAMESCOPE] + gs_args + ["--"] + inner

            log(f"Selected output: {chosen.name}")
            log(f"Selected mode: {chosen.current_mode.width}x{chosen.current_mode.height} @ {chosen.current_mode.hz} Hz")
            log(f"Adaptive Sync Support: {chosen.adaptive_sync_support}")
            log(f"HDR policy enabled: {chosen.is_internal_panel}")

            log("Final command:")
            log("  " + " ".join(full_cmd))
            if env_add:
                log("Env additions:")
                for k, v in env_add.items():
                    log(f"  {k}={v}")

            if DRYRUN:
                env_prefix = ""
                if env_add:
                    env_prefix = "env " + " ".join([f"{k}={v}" for k, v in env_add.items()]) + " "
                print("gamewrap-auto (dry-run): " + env_prefix + " ".join(full_cmd), file=sys.stderr)
                return 0

            os.execvpe(GAMESCOPE, full_cmd, env)
            return 0

        if __name__ == "__main__":
            raise SystemExit(main(sys.argv))
      '';
  };
in
{
  home.packages = with pkgs; [
    gamewrapAuto
    (heroic.override {
      extraPkgs = pkgs: [
        pkgs.gamescope
        pkgs.gamemode
      ];
    })
    minion
    prismlauncher
    (import inputs.creamlinux-installer { inherit pkgs; })
  ];

  xdg.configFile."gamescope/scripts/gamescope-explicit-sync-off.lua" = {
    force = true;
    text =
      # lua
      ''
        function info(text)
            gamescope.log(gamescope.log_priority.info, text)
        end


        info("Disabling explicit sync: " .. tostring(gamescope.convars.drm_debug_disable_explicit_sync.value) .. " -> " .. tostring(true))
        gamescope.convars.drm_debug_disable_explicit_sync.value = true
      '';
  };
}
