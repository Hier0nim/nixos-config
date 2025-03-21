{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.catppuccin.homeManagerModules.catppuccin

    ../common/programs
    ../common/config
    ../common/packages
    ../common/services
    ../common/shell
    ../common/window-managers/hyprland
  ];

  home = {
    username = "gaming";
    homeDirectory = "/home/gaming";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "wezterm";
      BROWSER = "firefox";
      SHELL = "nu";
      FLAKE = "$HOME/nixos-config";
    };

    preferXdgDirectories = true; # whether to make programs use XDG directories whenever supported
  };

  home.packages = with pkgs; [
    (heroic.override {
      extraPkgs = pkgs: [
        pkgs.gamescope
      ];
    })
    prismlauncher
    mangohud
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

    wallpaper = ../common/wallpapers/flamingo.png;
  };

  wayland.windowManager.hyprland.settings = {
    monitor = [
      # name, resolution@refresh-rate, position, scale
      "eDP-1, 2560x1600@165.00Hz, auto, 1.333333"
      ",preferred, auto, auto"
    ];
  };
}
