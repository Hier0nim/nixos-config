{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Resolve the wallpaper directory for this user's seed, not the old checkout.
  noctaliaSettings = pkgs.replaceVars ./files/noctalia/settings.toml {
    wallpaperDirectory = "${config.xdg.dataHome}/wallpapers";
  };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  # NixOS owns the compositor and shell service. Umbriel's files stay writable.
  programs.noctalia = {
    enable = true;
    package = null;
    # Nix manages these defaults; GUI preferences remain in the writable state file.
    settings.shell = {
      polkit_agent = true;
      session.power.suspend = "systemctl suspend-then-hibernate";
    };
  };

  home = {
    # Seed GUI preferences only. Never replace existing files or symlinks.
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
    sessionVariables.GSK_RENDERER = "gl";
    packages = with pkgs; [
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

  # Noctalia owns GTK theme and colors; retain only icon and cursor preferences.
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
