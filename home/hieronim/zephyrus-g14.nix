{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.catppuccin.homeModules.catppuccin

    ../common/programs
    ../common/packages/archive.nix
    ../common/packages/dev.nix
    ../common/packages/media.nix
    ../common/shell
    ../common/desktop-environments/kde
    ../common/config/cursor.nix
  ];

  home = {
    username = "hieronim";
    homeDirectory = "/home/hieronim";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "ghostty";
      BROWSER = "firefox";
      SHELL = "nu";
      FLAKE = "$HOME/nixos-config";
      USERNAME = "hieronim";
    };

    preferXdgDirectories = true; # whether to make programs use XDG directories whenever supported
  };

  home.packages = with pkgs; [
    teams-for-linux
    proton-pass
    remmina
    qbittorrent
    libreoffice
    protonvpn-gui
    protonmail-desktop
  ];
}
