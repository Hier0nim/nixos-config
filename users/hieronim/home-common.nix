{ config, lib, ... }:
{
  custom = {
    username = "hieronim";
    fullName = "Hier0nim";
    email = "hieronimdaniel@proton.me";
    repoPath = lib.custom.relativeToRoot ".";
    wallpaper = lib.custom.relativeToRoot "assets/wallpapers/koi.png";
  };

  home = {
    inherit (config.custom) username;
    homeDirectory = "/home/${config.custom.username}";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "ghostty";
      BROWSER = "firefox";
      SHELL = "nu";
      FLAKE = toString config.custom.repoPath;
      USERNAME = config.custom.username;
    };

    preferXdgDirectories = true; # whether to make programs use XDG directories whenever supported
  };
}
