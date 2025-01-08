{
  inputs,
  pkgs,
  lib,
  ...
}:

with lib;
let
  firefox-addons = inputs.firefox-addons.packages.${pkgs.system};
  arkenfoxConfig = builtins.readFile "${inputs.arkenfox-userjs}/user.js";

  # Relax some arkenfox settings, to get a less strict
  # alternative to Mullvad Browser to fallback on.
  sharedSettings = {
    # Enable restoring sessions
    "browser.startup.page" = 3;

    # Don't delete data on shutdown (cookies, sessions, windows, ...)
    "privacy.sanitize.sanitizeOnShutdown" = false;

    # Don't do default browser check
    "browser.shell.checkDefaultBrowser" = false;

    # Disable Pocket
    "extensions.pocket.enabled" = false;

    # Enable search in location bar
    "keyword.enabled" = true;

    # Enable IPv6 again
    "network.dns.disableIPv6" = false;

    # Disable extension auto updates
    "extensions.update.enabled" = false;
    "extensions.update.autoUpdateDefault" = false;

    # Use native file picker instead of GTK file picker
    "widget.use-xdg-desktop-portal.file-picker" = 1;
  };

  # Function to convert a preference value into a JSON-compatible string
  userPrefValue =
    pref:
    # Use builtins.toJSON to serialize the value
    # - If the value is a boolean, integer, or string, it converts directly to JSON
    # - For more complex types, it double-encodes as JSON for safety
    builtins.toJSON (if isBool pref || isInt pref || isString pref then pref else builtins.toJSON pref);

  # Function to generate a Firefox user.js configuration string from a set of preferences
  mkConfig =
    prefs:
    # Map over the preferences attribute set, converting each key-value pair
    concatStrings (
      # `mapAttrsToList` applies a function to each key-value pair in the attribute set
      mapAttrsToList (name: value: ''
        # Format each preference as a `user_pref("key", value);` entry
        user_pref("${name}", ${userPrefValue value});
      '') prefs
    );

  # use extraConfig to load arkenfox user.js before settings
  sharedExtraConfig = ''
    ${arkenfoxConfig}

    ${mkConfig sharedSettings}
  '';

  commonExtensions = with firefox-addons; [
    ublock-origin
    proton-pass
    tridactyl
  ];

  # use extraConfig to load arkenfox user.js before settings
  sharedBookmarks = [
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
in
{
  programs.firefox = {
    enable = true;
    policies = {
      # ---- EXTENSIONS ----
      # Check about:support for extension/add-on ID strings.
      # Valid strings for installation_mode are "allowed", "blocked",
      # "force_installed" and "normal_installed".
      ExtensionSettings = {
        # Catppuccin mocha
        "{8446b178-c865-4f5c-8ccc-1d7887811ae3}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/3990315/catppuccin_mocha_lavender_git-latest.xpi";
          installation_mode = "force_installed";
        };
        # GPThemes
        "gpthemes@itsmarta" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/4384792/gpthemes-latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
    nativeMessagingHosts = with pkgs; [ tridactyl-native ];
    profiles = {
      private = {
        id = 0;
        search.default = "DuckDuckGo";
        search.force = true;
        extraConfig = sharedExtraConfig;
        extensions = commonExtensions;
        bookmarks = sharedBookmarks;
      };
      work = {
        id = 1;
        search.default = "DuckDuckGo";
        search.force = true;
        extraConfig = sharedExtraConfig;
        extensions = commonExtensions;
        bookmarks = sharedBookmarks;
      };
    };
  };

  home.packages =
    let
      makeFirefoxProfileBin =
        args@{ profile, ... }:
        let
          name = "firefox-${profile}";
          scriptBin = pkgs.writeScriptBin name ''
            firefox -P "${profile}" --name="${name}" $@
          '';
          desktopFile = pkgs.makeDesktopItem (
            (removeAttrs args [ "profile" ])
            // {
              inherit name;
              exec = "${scriptBin}/bin/${name} %U";
              extraConfig.StartupWMClass = name;
              genericName = "Web Browser";
              mimeTypes = [
                "text/html"
                "text/xml"
                "application/xhtml+xml"
                "application/vnd.mozilla.xul+xml"
                "x-scheme-handler/http"
                "x-scheme-handler/https"
              ];
              categories = [
                "Network"
                "WebBrowser"
              ];
            }
          );
        in
        pkgs.runCommand name { } ''
          mkdir -p $out/{bin,share}
          cp -r ${scriptBin}/bin/${name} $out/bin/${name}
          cp -r ${desktopFile}/share/applications $out/share/applications
        '';
    in
    [
      (makeFirefoxProfileBin {
        profile = "work";
        desktopName = "Firefox (Work)";
        icon = "firefox";
      })
    ];

  xdg.configFile."tridactyl/tridactylrc".source = ./tridactylrc;
  xdg.configFile."tridactyl/themes/tridactyl-theme.css".source = ./tridactyl-theme.css;
}
