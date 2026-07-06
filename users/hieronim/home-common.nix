{ config, pkgs, ... }:
{
  custom = {
    username = "hieronim";
    fullName = "Hier0nim";
    email = "hieronimdaniel@proton.me";
    repoPath = ../..;
    worktreePath = "/home/${config.custom.username}/Projects/nixos-config";
    wallpaper = ../../assets/wallpapers/koi.png;
  };

  home = {
    inherit (config.custom) username;
    homeDirectory = "/home/${config.custom.username}";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "ghostty";
      BROWSER = "firefox";
      SHELL = "${pkgs.nushell}/bin/nu";
      FLAKE = config.custom.worktreePath;
      USERNAME = config.custom.username;
    };

    preferXdgDirectories = true; # whether to make programs use XDG directories whenever supported
  };
}
