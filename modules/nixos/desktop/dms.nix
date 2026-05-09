{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
{
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

  services = {
    accounts-daemon.enable = true;

    displayManager.dms-greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = config.users.users.hieronim.home;
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
}
