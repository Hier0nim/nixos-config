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
    inputs.nixvim.packages.x86_64-linux.default
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
    evince
    lazygit
    protonvpn-gui
    protonmail-desktop
    teams-for-linux
    remmina
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
      fm = "nemo.desktop";
      iv = "org.gnome.Loupe.desktop";
      ev = "org.gnome.Evince.desktop";
      mp = "mpv.desktop";
      te = "neovim.desktop";
    in
    rec {
      enable = true;
      associations.added = defaultApplications;
      defaultApplications = {
        # Office documents.
        "application/pdf" = ev;

        "inode/directory" = fm;
        "application/x-gnome-saved-search" = fm;

        # Web stuff. 
        "application/x-extension-htm" = br;
        "application/x-extension-html" = br;
        "application/x-extension-shtml" = br;
        "application/x-extension-xht" = br;
        "application/x-extension-xhtml" = br;
        "text/html" = br;
        "x-scheme-handler/http" = br;
        "x-scheme-handler/https" = br;
        "x-scheme-handler/chrome" = br;

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
