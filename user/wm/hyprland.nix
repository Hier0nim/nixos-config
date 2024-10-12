{
  pkgs,
  ...
}:

{
  imports = [
    ./hyprland/gtk.nix
    ./hyprland/hyprlock.nix
    ./hyprland/hypridle.nix
    ./hyprland/keybindings.nix
    ./hyprland/mako.nix
    ./hyprland/rofi.nix
    ./hyprland/rules.nix
    ./hyprland/services.nix
    ./hyprland/settings.nix
    ./hyprland/vesktop-settings.nix
    ./hyprland/waybar.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd = {
      enable = true;
      variables = [ "--all" ];
    };
  };

  nix.settings = {
    auto-optimise-store = true;
    extra-substituters = [ "https://hyprland.cachix.org" ];
    extra-trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

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
