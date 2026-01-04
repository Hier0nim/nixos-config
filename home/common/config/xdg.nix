{ lib, ... }:
{
  xdg = {
    enable = true;

    desktopEntries.nvim-ghostty = {
      name = "Neovim (Ghostty)";
      exec = "ghostty -e nvim %F";
      type = "Application";
      terminal = false;
      categories = [
        "Utility"
        "TextEditor"
      ];
      mimeType = [
        "text/plain"
        "application/json"
      ];
    };

    mimeApps =
      let
        imageViewer = [ "org.gnome.Loupe.desktop" ];
        mediaPlayer = [ "com.system76.CosmicPlayer.desktop" ];
        fileBrowser = [ "com.system76.CosmicFiles.desktop" ];
        webBrowser = [ "firefox.desktop" ];
        documentViewer = [ "org.gnome.Papers.desktop" ];
        editor = [ "nvim-ghostty.desktop" ];

        media = [
          "video/*"
          "audio/*"
        ];
        images = [ "image/*" ];
        browser = [
          "text/html"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/ftp"
          "x-scheme-handler/about"
          "x-scheme-handler/unknown"
        ];
        code = [
          "application/json"
          "text/plain"
        ];

        associations =
          (lib.genAttrs code (_: editor))
          // (lib.genAttrs media (_: mediaPlayer))
          // (lib.genAttrs images (_: imageViewer))
          // (lib.genAttrs browser (_: webBrowser))
          // {
            "inode/directory" = fileBrowser;
            "application/pdf" = documentViewer;

            "x-scheme-handler/spotify" = [ "spotify.desktop" ];
            "x-scheme-handler/discord" = [ "vesktop.desktop" ];
          };
      in
      {
        enable = true;
        defaultApplications = associations;
      };
  };
}
