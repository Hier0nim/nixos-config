{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.custom.desktop.dms;
in
{
  options.custom.desktop.dms.enable =
    lib.mkEnableOption "DMS desktop (niri compositor, display manager, portals)";

  config = lib.mkIf cfg.enable {
    programs = {
      niri.enable = true;
      kdeconnect.enable = true;
    };

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      config.niri = {
        default = lib.mkForce [
          "gtk"
        ];
        "org.freedesktop.impl.portal.Settings" = [ "gnome" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "gnome" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Access" = [ "gtk" ];
        "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };

    systemd.user.services = {
      xdg-desktop-portal.serviceConfig.Environment = [
        "XDG_CURRENT_DESKTOP=niri"
      ];
      xdg-desktop-portal-gtk.serviceConfig.Environment = [
        "XDG_CURRENT_DESKTOP=niri"
      ];
      xdg-desktop-portal-gnome.serviceConfig.Environment = [
        "XDG_CURRENT_DESKTOP=niri"
      ];
    };

    # Disable niri-flake's polkit agent to avoid conflict with DMS polkit
    systemd.user.services.niri-flake-polkit.enable = false;

    services = {
      accounts-daemon.enable = true;

      displayManager.dms-greeter = {
        enable = true;
        compositor.name = "niri";
        configHome = config.users.users.${config.custom.username}.home;
        package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };

      upower.enable = true;
      power-profiles-daemon.enable = true;
      ddccontrol.enable = true;
    };

    programs.dconf.enable = true;

    environment.systemPackages = with pkgs; [
      ddcutil
      ddcui
    ];
  };
}
