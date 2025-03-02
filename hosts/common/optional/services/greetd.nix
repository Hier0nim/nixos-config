{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.autoLogin;
in
{
  # Declare custom options for conditionally enabling auto login
  options.autoLogin = {
    enable = lib.mkEnableOption "Enable automatic login";

    username = lib.mkOption {
      type = lib.types.str;
      default = "guest";
      description = "User to automatically login";
    };
  };

  config = {
    services.greetd = {
      enable = true;

      restart = true;
      settings = {
        default_session = {
          command = lib.concatStringsSep " " [
            (lib.getExe pkgs.greetd.tuigreet)
            "--cmd '${lib.getExe config.programs.hyprland.package}'"
            "--remember"
            "--remember-session"
            "--asterisks"
            "--time"
          ];
          user = "greeter";
        };

        initial_session = lib.mkIf cfg.enable {
          command = "${pkgs.hyprland}/bin/Hyprland";
          user = "${cfg.username}";
        };
      };
    };
    security.pam.services.greetd.enableGnomeKeyring =
      lib.mkIf config.services.gnome.gnome-keyring.enable true;
  };
}
