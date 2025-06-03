{ inputs, pkgs, ... }:
{
  imports = [
    inputs.cosmic-manager.homeManagerModules.cosmic-manager

    ./apps/cosmic-files.nix
    ./applets.nix
    ./compositor.nix
    ./panels.nix
    ./shortcuts.nix
    ./theme
  ];

  wayland.desktopManager.cosmic = {
    enable = true;
    resetFiles = false;
  };

  home.packages = with pkgs; [
    brightnessctl
  ];
}
