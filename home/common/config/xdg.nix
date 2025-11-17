{ config, lib, ... }:
{
  xdg = {
    enable = true;
    cacheHome = config.home.homeDirectory + "/.local/cache";
    userDirs = {
      enable = true;
      createDirectories = true;
      extraConfig = {
        XDG_SCREENSHOTS_DIR = "${config.xdg.userDirs.pictures}/Screenshots";
      };
    };
    mimeApps =
      let
        imageViewer = [ "org.gnome.Loupe" ];
        mediaPlayer = [ "io.github.celluloid_player.Celluloid" ];
        fileBrowser = [ "com.system76.CosmicFiles" ];
        webBrowser = [ "firefox" ];
        documentViewer = [ "org.gnome.Papers" ];
        editor = [ "ghostty -e nvim" ];

        media = [
          "video/*"
          "audio/*"
        ];

        images = [ "image/*" ];

        browser = [
          "text/html"
          "application/pdf"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/ftp"
          "x-scheme-handler/about"
          "x-scheme-handler/unknown"
        ];

        code = [
          "application/json"
          "text/english"
          "text/plain"
        ];
        # XDG MIME types
        associations =
          (lib.genAttrs code (_: editor))
          // (lib.genAttrs media (_: mediaPlayer))
          // (lib.genAttrs images (_: imageViewer))
          // (lib.genAttrs browser (_: webBrowser))
          // {
            "x-scheme-handler/spotify" = [ "spotify.desktop" ];
            "x-scheme-handler/discord" = [ "vesktop.desktop" ];
            "inode/directory" = fileBrowser;
            "application/pdf" = documentViewer;
          };
      in
      {
        enable = true;
        defaultApplications = associations;
      };
  };
}
