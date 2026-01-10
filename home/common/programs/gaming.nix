{ pkgs, ... }:
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

        import os
        import re
        import sys
        import subprocess
        from dataclasses import dataclass
        from typing import Optional


        COSMIC_RANDR = "${pkgs.cosmic-randr}/bin/cosmic-randr"
        GAMESCOPE    = "${pkgs.gamescope}/bin/gamescope"
        GAMEMODERUN  = "${pkgs.gamemode}/bin/gamemoderun"


        def env_flag(name: str, default: str = "0") -> bool:
            return os.environ.get(name, default) == "1"


        DEBUG = env_flag("GAMEWRAP_DEBUG")
        DRYRUN = env_flag("GAMEWRAP_DRYRUN")


        # -------------------------
        # Debug helpers
        # -------------------------
        def log(msg: str) -> None:
            if DEBUG:
                print(f"gamewrap-auto: {msg}", file=sys.stderr)


        def dump_text(label: str, text: str, max_lines: int = 250) -> None:
            """
            Prints line-numbered repr() lines, so you can see hidden characters
            like '\\r', '\\t', or stray control bytes.
            """
            if not DEBUG:
                return
            print(f"----- {label} -----", file=sys.stderr)
            lines = text.splitlines(True)  # keep line endings
            for i, ln in enumerate(lines[:max_lines], start=1):
                print(f"{i:04d}: {ln!r}", file=sys.stderr)
            if len(lines) > max_lines:
                print(f"... ({len(lines) - max_lines} more lines)", file=sys.stderr)
            print(f"----- end {label} -----", file=sys.stderr)


        # -------------------------
        # Sanitization
        # -------------------------
        ANSI_CSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")  # ESC[... (CSI)
        ANSI_OSC_RE = re.compile(r"\x1b\][^\x07]*\x07")         # ESC]...BEL (OSC)
        ANSI_ST_RE  = re.compile(r"\x1b\\")                     # ESC\ (String Terminator)

        # Some tools produce leftover "[1m" fragments if ESC got eaten somewhere.
        SGR_LEFTOVER_RE = re.compile(r"(?<!\x1b)\[[0-9;?]*m")

        # Keep: \n, \t. Turn other control chars into visible escape tokens.
        # Control ranges: 0x00-0x08, 0x0b-0x1f, 0x7f. (we'll also handle CR separately)
        CTRL_TO_VISIBLE = {
            **{i: f"\\x{i:02x}" for i in range(0x00, 0x09)},
            **{i: f"\\x{i:02x}" for i in range(0x0b, 0x20)},
            0x7f: "\\x7f",
        }

        def sanitize_text(s: str) -> str:
            """
            Goal:
            - Make parsing stable (remove ANSI)
            - Normalize newlines
            - Make hidden control chars visible in DEBUG dumps
            """
            # Normalize Windows CRLF and stray CR
            s = s.replace("\r\n", "\n").replace("\r", "\n")

            # Strip common ANSI sequences (CSI/OSC/ST)
            s = ANSI_OSC_RE.sub("", s)
            s = ANSI_CSI_RE.sub("", s)
            s = ANSI_ST_RE.sub("", s)
            s = SGR_LEFTOVER_RE.sub("", s)

            # Make remaining control chars visible (except \n and \t)
            s = s.translate(CTRL_TO_VISIBLE)

            return s


        # -------------------------
        # Parsing cosmic-randr output
        # -------------------------
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
            enabled: bool
            xwayland_primary: bool
            adaptive_sync_support: bool
            current_mode: Mode
            raw_block: str

            @property
            def is_internal_panel(self) -> bool:
                return self.name.startswith("eDP-")


        HEADER_RE = re.compile(r"^([A-Za-z0-9-]+)\s+\((enabled|disabled)\)\s*$")

        # Mode line example:
        # "2560x1600 @ 165.000 Hz (current) (preferred)"
        CURRENT_MODE_RE = re.compile(
            r"^\s*(\d{3,5})x(\d{3,5})\s*@\s*([0-9]+(?:\.[0-9]+)?)\s*Hz\b.*\(\s*current\s*\)",
            re.IGNORECASE,
        )

        def parse_bool_field(block: str, field: str, default: bool = False) -> bool:
            m = re.search(
                rf"^\s*{re.escape(field)}:\s*(true|false)\s*$",
                block,
                flags=re.MULTILINE,
            )
            if not m:
                return default
            return m.group(1) == "true"


        def split_blocks(text: str) -> list[tuple[str, bool, str]]:
            """
            Returns [(name, enabled, block_text), ...]
            Each block starts with: "DP-8 (enabled)".
            """
            blocks: list[tuple[str, bool, str]] = []
            cur_name: Optional[str] = None
            cur_enabled: Optional[bool] = None
            cur_lines: list[str] = []

            def flush() -> None:
                nonlocal cur_name, cur_enabled, cur_lines
                if cur_name is not None and cur_enabled is not None:
                    blocks.append((cur_name, cur_enabled, "\n".join(cur_lines)))
                cur_name, cur_enabled, cur_lines = None, None, []

            for line in text.splitlines():
                m = HEADER_RE.match(line.strip())
                if m:
                    flush()
                    cur_name = m.group(1)
                    cur_enabled = (m.group(2) == "enabled")
                    cur_lines = [line]
                else:
                    if cur_name is not None:
                        cur_lines.append(line)

            flush()
            return blocks


        def parse_current_mode(block: str, output_name: str) -> Mode:
            for line in block.splitlines():
                m = CURRENT_MODE_RE.match(line)
                if m:
                    if DEBUG:
                        dump_text(f"{output_name} current mode line (matched)", line + "\n", max_lines=10)
                    return Mode(
                        width=int(m.group(1)),
                        height=int(m.group(2)),
                        hz=float(m.group(3)),
                    )

            if DEBUG:
                dump_text(f"{output_name} block (NO current mode match)", block, max_lines=120)
            raise SystemExit(f"gamewrap-auto: could not find current mode line for {output_name}")


        def parse_output_info(name: str, enabled: bool, block: str) -> Optional[OutputInfo]:
            if not enabled:
                return None

            xwayland_primary = bool(re.search(r"^\s*Xwayland primary:\s*true\s*$", block, flags=re.MULTILINE))
            adaptive_sync_support = parse_bool_field(block, "Adaptive Sync Support", default=False)
            mode = parse_current_mode(block, name)

            return OutputInfo(
                name=name,
                enabled=True,
                xwayland_primary=xwayland_primary,
                adaptive_sync_support=adaptive_sync_support,
                current_mode=mode,
                raw_block=block,
            )


        def choose_output(outputs: list[OutputInfo]) -> OutputInfo:
            if not outputs:
                raise SystemExit("gamewrap-auto: no enabled display found in cosmic-randr output")

            if DEBUG:
                print("----- candidates -----", file=sys.stderr)
                for o in outputs:
                    print(
                        f"- {o.name}: xwayland_primary={o.xwayland_primary} "
                        f"vrr_support={o.adaptive_sync_support} "
                        f"mode={o.current_mode.width}x{o.current_mode.height}@{o.current_mode.hz}",
                        file=sys.stderr,
                    )
                print("----- end candidates -----", file=sys.stderr)

            for o in outputs:
                if o.xwayland_primary:
                    log(f"Picked {o.name} because Xwayland primary=true")
                    return o

            log(f"Picked {outputs[0].name} because it's the first enabled output")
            return outputs[0]


        # -------------------------
        # Running cosmic-randr
        # -------------------------
        @dataclass(frozen=True)
        class CmdOut:
            stdout: str
            stderr: str
            returncode: int


        def run_cosmic_randr_list() -> CmdOut:
            env = os.environ.copy()
            env["NO_COLOR"] = "1"
            env["TERM"] = "dumb"

            p = subprocess.run(
                [COSMIC_RANDR, "list"],
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

            # Always keep raw text; sanitize only for parsing/dumps
            raw_out = p.stdout or ""
            raw_err = p.stderr or ""

            if DEBUG:
                dump_text("cosmic-randr stdout (RAW)", raw_out)
                dump_text("cosmic-randr stderr (RAW)", raw_err)

                dump_text("cosmic-randr stdout (SANITIZED)", sanitize_text(raw_out))
                dump_text("cosmic-randr stderr (SANITIZED)", sanitize_text(raw_err))

            if p.returncode != 0:
                print("gamewrap-auto: cosmic-randr list failed", file=sys.stderr)
                print(raw_err, file=sys.stderr)
                raise SystemExit(p.returncode)

            return CmdOut(stdout=raw_out, stderr=raw_err, returncode=p.returncode)


        # -------------------------
        # Gamescope args + env policy
        # -------------------------
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

            cmd = run_cosmic_randr_list()

            # Parse sanitized output for stability
            clean_out = sanitize_text(cmd.stdout)
            blocks = split_blocks(clean_out)

            if DEBUG:
                print("----- parsed blocks -----", file=sys.stderr)
                for idx, (name, enabled, block) in enumerate(blocks, start=1):
                    print(f"[{idx}] {name} enabled={enabled} lines={len(block.splitlines())}", file=sys.stderr)
                    dump_text(f"block {idx}: {name}", block, max_lines=90)
                print("----- end parsed blocks -----", file=sys.stderr)

            outputs: list[OutputInfo] = []
            for name, enabled, block in blocks:
                oi = parse_output_info(name, enabled, block)
                if oi:
                    outputs.append(oi)

            chosen = choose_output(outputs)

            gs_args, env_add = build_gamescope_args(chosen)
            inner = [GAMEMODERUN] + argv[1:]
            full_cmd = [GAMESCOPE] + gs_args + ["--"] + inner

            env = os.environ.copy()
            env.update(env_add)

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
        pkgs.cosmic-randr
      ];
    })
    prismlauncher
    lutris
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
