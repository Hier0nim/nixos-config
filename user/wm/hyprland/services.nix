{
  config,
  pkgs,
  lib,
  ...
}:
let
  suspendScript = pkgs.writeShellScriptBin "script" ''
    ${pkgs.pipewire}/bin/pw-cli i all 2>&1 | ${pkgs.ripgrep}/bin/rg running -q
    # only suspend if audio isn't running
    if [ $? == 1 ]; then
      ${pkgs.systemd}/bin/systemctl suspend
    fi
  '';
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
