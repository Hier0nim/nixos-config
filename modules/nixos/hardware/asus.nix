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

    rogControlCenterSessionTarget = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      description = "User target reached after the compositor exports its session environment.";
    };

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
      # The user service below is the only startup path.
      autoStart = false;
    };

    systemd.user.services.rog-control-center = {
      description = "rog-control-center";

      after = [ cfg.rogControlCenterSessionTarget ];
      partOf = [ cfg.rogControlCenterSessionTarget ];
      wantedBy = [ cfg.rogControlCenterSessionTarget ];

      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";

      serviceConfig = {
        Type = "simple";
        # Wait for Noctalia's tray watcher, not an arbitrary delay.
        ExecStartPre = "${lib.getExe' pkgs.glib.bin "gdbus"} wait --session --timeout 60 org.kde.StatusNotifierWatcher";
        ExecStart = "${lib.getExe' pkgs.asusctl "rog-control-center"} --autostart --background";
        # Quitting the app must leave it stopped.
        Restart = "no";
        TimeoutStartSec = 65;
        TimeoutStopSec = 10;
      };
    };
  };
}
