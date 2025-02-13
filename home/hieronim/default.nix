{ lib, inputs, ... }:
{
  imports = [
    inputs.catppuccin.homeManagerModules.catppuccin

    ./config
    ./packages
    ./programs
    ./services
    ./shell
    ./window-managers/hyprland

    ./home.nix
  ];

  # Catppuccin Mocha
  theme = {
    colorscheme = rec {
      colors = {
        rosewater = "F5E0dc";
        flamingo = "F2cdcd";
        pink = "F5c2e7";
        mauve = "cba6f7";
        red = "f38ba8";
        maroon = "eba0ac";
        peach = "fab387";
        yellow = "f9e2af";
        green = "a6e3a1";
        teal = "94e2d5";
        blue = "89b4fa";
        sky = "89dceb";
        lavender = "b4befe";

        # Grayscale / background layers
        black0 = "11111b"; # crust
        black1 = "181825"; # mantle
        black2 = "1e1e2e"; # base
        black3 = "313244"; # surface0
        black4 = "45475a"; # surface1
        gray0 = "585b70"; # surface2
        gray1 = "6c7086"; # overlay0
        gray2 = "7f849c"; # overlay1

        white = "cdd6f4"; # text
      };

      xcolors = lib.mapAttrsRecursive (_: color: "#${color}") colors;
    };

    wallpaper = ./wallpapers/bkg1.png;
  };

  wayland.windowManager.hyprland.settings = {
    monitor = [
      # name, resolution, position, scale
      "eDP-1, preferred, auto, 1.333333"
      ",preferred, auto, auto"
    ];
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    TERM = "wezterm";
    BROWSER = "firefox";
  };
}
