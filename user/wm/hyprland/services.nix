{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (import ./scripts.nix { inherit pkgs; }) suspendScript;
in
{
  services = {
    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };

    network-manager-applet.enable = true;
    blueman-applet.enable = true;

    hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = lib.getExe config.programs.hyprlock.package;
          before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
          ignore_dbus_inhibit = false;
        };

        listeners = [
          {
            timeout = 600;
            onTimeout = lib.getExe config.programs.hyprlock.package;
          }
          {
            timeout = 1200;
            onTimeout = "${suspendScript}/bin/script";
          }
        ];
      };
    };

    cliphist.enable = true;
  };
}
