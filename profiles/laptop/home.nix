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
    ../../user/apps
    ../../user/shell
    (./. + "../../../user/wm" + ("/" + "${settings.wm}") + ".nix")
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
    sway-contrib.grimshot
    libreoffice-fresh
    obs-studio
    tty-clock
    qbittorrent
    swayimg
    vesktop
    drawio
    gimp
    mpv
    loupe
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
  xdg.mimeApps =
    let
      br = "${settings.browser}.desktop";
      fm = "org.Nautilus.desktop";
      iv = "org.gnome.Loupe.desktop";
      mp = "mpv.desktop";
      te = "neovim.desktop";
    in
    rec {
      enable = true;
      associations.added = defaultApplications;
      defaultApplications = {
        # Office documents.
        "application/pdf" = br;

        "inode/directory" = fm;

        # Web stuff.
        "application/xhtml+xml" = br;
        "text/html" = br;
        "x-scheme-handler/http" = br;
        "x-scheme-handler/https" = br;

        # Images.
        "image/avif" = iv;
        "image/gif" = iv;
        "image/jpeg" = iv;
        "image/jpg" = iv;
        "image/pjpeg" = iv;
        "image/png" = iv;
        "image/tiff" = iv;
        "image/webp" = iv;
        "image/x-bmp" = iv;
        "image/x-gray" = iv;
        "image/x-icb" = iv;
        "image/x-ico" = iv;
        "image/x-png" = iv;

        # Plain text & code.
        "application/x-shellscript" = te;
        "text/plain" = te;

        # Videos.
        "video/mkv" = mp;
        "video/mp4" = mp;
        "video/webm" = mp;
      };
    };

  home.sessionVariables = {
    EDITOR = settings.editor;
    TERM = settings.term;
    BROWSER = settings.browser;
  };

  programs = {
    starship.catppuccin.enable = true;
    bat.catppuccin.enable = true;
    btop.catppuccin.enable = true;
    yazi.catppuccin.enable = true;
    zellij.catppuccin.enable = true;
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