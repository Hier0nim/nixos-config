{ pkgs, ... }:

{
  xdg = {
    enable = true;
    portal = with pkgs; {
      enable = true;
      configPackages = [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
        xdg-desktop-portal
      ];
      extraPortals = [
        xdg-desktop-portal-gtk
        xdg-desktop-portal
      ];
      xdgOpenUsePortal = true;
    };
  };
}
