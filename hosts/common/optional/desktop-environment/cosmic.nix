{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  options.desktopManager.cosmicCustom.enable = mkEnableOption "System76 COSMIC desktop with greeter and tweaks";

  config = mkIf config.desktopManager.cosmicCustom.enable {
    environment = {
      sessionVariables = {
        COSMIC_DATA_CONTROL_ENABLED = 1;
      };

      cosmic.excludePackages = with pkgs; [
        cosmic-store
        cosmic-term
        cosmic-initial-setup
      ];

      systemPackages = with pkgs; [
        wl-clipboard
        # cosmic-ext-applet-external-monitor-brightness
        cosmic-ext-tweaks
        gnome-keyring
      ];
    };

    services.desktopManager.cosmic.enable = true;
    services.displayManager.cosmic-greeter.enable = true;

    security.pam.services.cosmic-greeter.enableGnomeKeyring = true;

    systemd.tmpfiles.rules = [
      "L /usr/bin/gnome-keyring-daemon - - - - ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon"
    ];
  };
}
