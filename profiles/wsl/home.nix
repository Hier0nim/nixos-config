{
  pkgs,
  lib,
  config,
  inputs,
  settings,
  ...
}:
{
  imports = [
    ../../user/apps/git.nix
    ../../user/shell
    inputs.catppuccin.homeManagerModules.catppuccin
  ];

  # Info required by home-manager and some session variables.
  home = {
    username = "${settings.username}";
    homeDirectory = "/home/${settings.username}";
    stateVersion = "${settings.stateVersion}";
  };

  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    inputs.nixvim.packages.x86_64-linux.default
    libreoffice-fresh
    tty-clock
    swayimg
    wl-clipboard
    lazygit
  ];

  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    music = "${config.home.homeDirectory}/Media/Music";
    videos = "${config.home.homeDirectory}/Media/Videos";
    pictures = "${config.home.homeDirectory}/Media/Pictures";
    download = "${config.home.homeDirectory}/Downloads";
    documents = "${config.home.homeDirectory}/Documents";
    templates = null;
    desktop = null;
    publicShare = null;
    extraConfig = {
      XDG_BOOK_DIR = "${config.home.homeDirectory}/Media/Books";
    };
  };

  home.sessionVariables = {
    EDITOR = settings.editor;
  };

  wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
  };

  nix = {
    # Keep build-time dependencies around to be able to rebuild while being offline.
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';

    registry = lib.mapAttrs (_: v: { flake = v; }) inputs;
    package = pkgs.nix;

    # Enable auto cleanup.
    gc = {
      automatic = true;
      frequency = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  programs.home-manager.enable = true;
}
