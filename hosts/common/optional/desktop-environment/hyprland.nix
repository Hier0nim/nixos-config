{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [
        "gtk"
        "hyprland"
      ];
    };

    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Allow hyprlock to unlock the screen
  security.pam.services.hyprlock = { };

  programs.xwayland = {
    enable = true;
  };
}
