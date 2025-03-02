{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.autoLogin;
in {
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
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --asterisks --time --time-format '%I:%M %p | %a • %h | %F' --cmd Hyprland";
          user = "ta";
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
