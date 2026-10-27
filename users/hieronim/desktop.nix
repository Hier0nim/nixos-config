{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  noctaliaSettings = pkgs.replaceVars ./files/noctalia/settings.toml {
    wallpaperDirectory = "${config.xdg.dataHome}/wallpapers";
  };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "JetBrainsMono Nerd Font Mono";
      font-size = 12;
      theme = "Kanagawa Wave";
      resize-overlay = "never";
      window-decoration = "none";
    };
  };

  systemd.user.services.zellij-cleanup = {
    Unit = {
      Description = "Stop Zellij sessions when the graphical session ends";
      PartOf = [ "graphical-session.target" ];
      Before = [ "exit.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "-${lib.getExe pkgs.zellij} kill-all-sessions -y";
      TimeoutStopSec = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.noctalia = {
    enable = true;
    package = null; # Installed by NixOS.
    settings.shell = {
      polkit_agent = true;
      session.power.suspend = "systemctl suspend-then-hibernate";
    };
  };

  home = {
    # Seed settings once; keep later GUI edits.
    activation.seedNoctalia = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      settingsFile=${lib.escapeShellArg "${config.xdg.stateHome}/noctalia/settings.toml"}

      if [[ ! -e "$settingsFile" && ! -L "$settingsFile" ]]; then
        run install -Dm600 ${noctaliaSettings} "$settingsFile"
      fi
    '';

    pointerCursor = {
      enable = true;
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    sessionVariables = {
      BROWSER = "firefox";
      GSK_RENDERER = "gl";
    };
    packages = with pkgs; [
      ffmpegthumbnailer
      poppler
      wl-clipboard
      adw-gtk3
      papirus-icon-theme
      celluloid
      gpu-screen-recorder
      loupe
      nautilus
      papers
    ];
  };
  systemd.user.sessionVariables.GSK_RENDERER = "gl";

  # Noctalia manages GTK theme and colors.
  dconf.settings."org/gnome/desktop/interface" = {
    icon-theme = "Papirus-Dark";
    cursor-theme = "Bibata-Modern-Classic";
    cursor-size = 24;
  };

  xdg = {
    dataFile."wallpapers/fear-samori.png".source = ./files/noctalia/fear-samori.png;
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = false;
    };
    desktopEntries.nvim-ghostty = {
      name = "Neovim (Ghostty)";
      exec = "ghostty -e nvim %F";
      categories = [
        "Utility"
        "TextEditor"
      ];
      mimeType = [
        "text/plain"
        "application/json"
      ];
    };
    mimeApps = {
      enable = true;
      defaultApplications =
        (lib.genAttrs [
          "text/plain"
          "application/json"
        ] (_: [ "nvim-ghostty.desktop" ]))
        // (lib.genAttrs [
          "text/html"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/ftp"
          "x-scheme-handler/about"
          "x-scheme-handler/unknown"
        ] (_: [ "firefox.desktop" ]))
        // (lib.genAttrs [
          "image/jpeg"
          "image/png"
          "image/gif"
          "image/webp"
          "image/avif"
          "image/tiff"
          "image/bmp"
          "image/svg+xml"
        ] (_: [ "org.gnome.Loupe.desktop" ]))
        // (lib.genAttrs [
          "audio/mpeg"
          "audio/flac"
          "audio/ogg"
          "audio/opus"
          "audio/mp4"
          "audio/x-wav"
          "video/mp4"
          "video/webm"
          "video/ogg"
          "video/x-matroska"
          "video/x-msvideo"
          "video/quicktime"
        ] (_: [ "io.github.celluloid_player.Celluloid.desktop" ]))
        // {
          "application/pdf" = [ "org.gnome.Papers.desktop" ];
          "application/acrobat" = [ "org.gnome.Papers.desktop" ];
          "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
        };
    };
  };
}
