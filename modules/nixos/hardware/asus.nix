{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom.hardware.asus;
in
{
  options.custom.hardware.asus = {
    enable = lib.mkEnableOption "ASUS laptop services (asusd, supergfxd, lact, rog-control-center)";

    asusdConfigPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to the asusd.ron configuration file.";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      asusd = {
        enable = true;
        asusdConfig.source = cfg.asusdConfigPath;
      };

      supergfxd.enable = lib.mkDefault true;

      lact.enable = true;

      asus-px-keyboard-tool = {
        enable = true;
        settings = {
          kb_brightness_cycle = {
            enabled = true;
            keycode = "KEY_PROG3";
          };
        };
      };
    };

    programs.rog-control-center = {
      enable = true;
      autoStart = false;
    };

    systemd.user.services.rog-control-center = {
      description = "rog-control-center";

      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];

      startLimitBurst = 5;
      startLimitIntervalSec = 120;

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe' pkgs.asusctl "rog-control-center";
        Restart = "always";
        RestartSec = 1;
        TimeoutStopSec = 10;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      };
    };
  };
}
