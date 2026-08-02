{
  config,
  lib,
  pkgs,
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

    systemd = {
      user.services = {
        xdg-desktop-portal.serviceConfig.Environment = [
          "XDG_CURRENT_DESKTOP=niri"
        ];
        xdg-desktop-portal-gtk.serviceConfig.Environment = [
          "XDG_CURRENT_DESKTOP=niri"
        ];
        xdg-desktop-portal-gnome.serviceConfig.Environment = [
          "XDG_CURRENT_DESKTOP=niri"
        ];

        # Disable niri-flake's polkit agent to avoid conflict with DMS polkit
        niri-flake-polkit.enable = false;
      };

      # Old greeter releases left hidden XDG cache directories owned by a retired
      # system account. The upstream pre-start hook only chowns `*`, which omits
      # dot-directories; make the cache writable before each greeter launch.
      services.greetd.preStart = lib.mkAfter ''
        chown -R greeter:greeter /var/lib/dms-greeter
      '';
    };

    services = {
      accounts-daemon.enable = true;
      upower.enable = true;
      power-profiles-daemon.enable = true;
      ddccontrol.enable = true;
    };

    programs.dms-greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = config.users.users.${config.custom.username}.home;
    };

    programs.dconf.enable = true;

    environment.systemPackages = with pkgs; [
      ddcutil
      ddcui
    ];
  };
}
