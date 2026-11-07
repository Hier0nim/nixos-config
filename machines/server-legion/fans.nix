{ config, pkgs, ... }:
let
  kernel = config.boot.kernelPackages.kernel;
  driver = config.boot.kernelPackages.lenovo-legion-module.overrideAttrs {
    # Upstream's manual copy omits the module digest required by this kernel.
    installPhase = ''
      runHook preInstall
      flagsArray=()
      concatTo flagsArray makeFlags makeFlagsArray
      make "''${flagsArray[@]}" -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M="$PWD" INSTALL_MOD_PATH="$out" INSTALL_MOD_DIR=kernel/drivers/platform/x86 \
        DEPMOD=true modules_install
      runHook postInstall
    '';
  };
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
  stock = "/var/lib/legion-fans/9VCN22WW/stock.yaml";
  preset = "/etc/legion-linux/quiet-9VCN22WW.yaml";

  # Apply a curve file and verify that the controller accepted every point.
  setCurve =
    curve:
    pkgs.writeShellScript "legion-fan-curve" ''
      set -euo pipefail
      [[ $(</sys/class/dmi/id/bios_version) == 9VCN22WW ]]
      test -s ${stock}
      if [[ $(</sys/module/legion_laptop/parameters/ec_readonly) != N ]]; then
        echo 'Reload legion_laptop with ec_readonly=0 before starting fan control' >&2
        exit 1
      fi
      readback=$(mktemp)
      trap 'rm -f "$readback"' EXIT
      legion_cli fancurve-write-file-to-hw ${curve}
      legion_cli fancurve-write-hw-to-file "$readback"
      ${python}/bin/python - ${curve} "$readback" <<'PY'
      import sys
      from pathlib import Path
      import yaml

      expected, actual = [yaml.safe_load(Path(p).read_text()) for p in sys.argv[1:]]
      if any(actual[k] != expected[k] for k in ("entries", "enable_minifancurve")):
          raise SystemExit("Fan curve readback does not match the requested curve")
      PY
    '';
in
{
  boot = {
    extraModulePackages = [ driver ];
    kernelModules = [ "legion_laptop" ];
    extraModprobeConfig = ''
      options legion_laptop ec_readonly=0 enable_platformprofile=0
    '';
  };

  environment = {
    systemPackages = [ pkgs.lenovo-legion ];
    etc."legion-linux/quiet-9VCN22WW.yaml".source = ./fans/quiet-9VCN22WW.yaml;
  };

  systemd.services.legion-fans = {
    description = "Apply the Legion quiet fan curve";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    path = [
      pkgs.bash
      pkgs.lenovo-legion
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = setCurve preset;
      # Also restore after a failed or partially applied start.
      ExecStopPost = setCurve stock;
      StateDirectory = "legion-fans/9VCN22WW";
      StateDirectoryMode = "0700";
      UMask = "0077";
      PrivateTmp = true;
      TimeoutStartSec = "30s";
      TimeoutStopSec = "30s";
    };
  };

  powerManagement.resumeCommands = ''
    ${config.systemd.package}/bin/systemctl --no-block try-restart legion-fans.service
  '';
}
