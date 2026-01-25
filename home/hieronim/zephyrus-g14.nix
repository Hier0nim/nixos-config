{
  pkgs,
  ...
}:
{
  imports = [
    ../common/programs
    ../common/packages/archive.nix
    ../common/packages/dev.nix
    ../common/packages/media.nix
    ../common/programs/gaming.nix
    ../common/programs/ssh.nix
    ../common/shell
    ../common/desktop-environments/cosmic
    ../common/config/cursor.nix
    ../common/config/xdg.nix
    ../common/services/suspend.nix
    ../common/services/copyq.nix
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
    protonvpn-gui
    protonmail-desktop
    comma
    libreoffice-fresh
  ];
}
