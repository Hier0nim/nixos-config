{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.catppuccin.homeModules.catppuccin

    ../common/programs
    ../common/packages/media.nix
    ../common/shell
    ../common/desktop-environments/kde
  ];

  home = {
    username = "gaming";
    homeDirectory = "/home/gaming";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "ghostty";
      BROWSER = "firefox";
      SHELL = "nu";
      FLAKE = "$HOME/nixos-config";
      USERNAME = "gaming";
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
}
