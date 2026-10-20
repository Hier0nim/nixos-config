{
  config,
  inputs,
  pkgs,
  ...
}:
{
  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    nativeMessagingHosts = [ pkgs.tridactyl-native ];

    profiles.private = {
      id = 0;
      search = {
        default = "ddg";
        force = true;
      };

      preConfig = builtins.readFile "${inputs.arkenfox-userjs}/user.js";
      settings = {
        "browser.startup.page" = 3;
        "privacy.sanitize.sanitizeOnShutdown" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "extensions.pocket.enabled" = false;
        "keyword.enabled" = true;
        "media.hardware-video-decoding.enabled" = false;
        "network.dns.disableIPv6" = false;
        "extensions.update.enabled" = false;
        "extensions.update.autoUpdateDefault" = false;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "sidebar.revamp" = true;
        "sidebar.verticalTabs" = true;
        "sidebar.revamp.round-content-area" = true;
      };
      extensions.packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
        ublock-origin
        proton-pass
        tridactyl
        pywalfox
      ];
      bookmarks = {
        force = true;
        settings = [
          {
            name = "Nix sites";
            toolbar = true;
            bookmarks = [
              {
                name = "homepage";
                url = "https://nixos.org/";
              }
              {
                name = "wiki";
                tags = [
                  "wiki"
                  "nix"
                ];
                url = "https://wiki.nixos.org/";
              }
              {
                name = "Nixpkgs";
                url = "https://search.nixos.org/";
              }
              {
                name = "Home-manager";
                url = "https://home-manager-options.extranix.com/";
              }
            ];
          }
        ];
      };
    };
  };

  home.packages = [ pkgs.pywalfox-native ];
  xdg.configFile."tridactyl/tridactylrc".source = ./files/tridactylrc;
}
