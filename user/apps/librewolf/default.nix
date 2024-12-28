{
  pkgs,
  lib,
  ...
}:

let
  # Import your custom LibreWolf overlay
  librewolf-overlay = import ./nix/overlay.nix;

  # Import bookmarks and extensions configurations
  bookmarks = import ./bookmarks.nix { inherit lib; };
  extensions = import ./extensions.nix;

  # Define the custom LibreWolf package with your preferences and policies
  librewolf-custom = pkgs.wrapFirefox pkgs.librewolf-unwrapped {
    inherit (pkgs.librewolf-unwrapped) extraPrefsFiles extraPoliciesFiles;
    wmClass = "LibreWolf";
    libName = "librewolf";
    nativeMessagingHosts = with pkgs; [ tridactyl-native ];

    # Extra preferences for LibreWolf
    extraPrefs = # javascript
      ''
        pref("accessibility.force_disabled", 1);
        pref("browser.aboutConfig.showWarning", false);
        pref("browser.bookmarks.addedImportButton", false);
        pref("browser.migrate.bookmarks-file.enabled", false);
        pref("browser.shell.checkDefaultBrowser", false);
        pref("browser.toolbars.bookmarks.visibility", "newtab");
        pref("browser.translations.neverTranslateLanguages", "pl");
        pref("extensions.autoDisableScopes", 0);
        pref("extensions.install_origins.enabled", true);
        pref("general.autoScroll", true);
        pref("gfx.canvas.accelerated", true);
        pref("gfx.webrender.enabled", true);
        pref("middlemouse.paste", false);

        // Privacy-related preferences
        pref("privacy.resistFingerprinting.exemptedDomains", "*.claude.ai");
      '';

    # Policies for LibreWolf (such as bookmarks and extensions)
    extraPolicies = {
      Bookmarks = bookmarks;
      ExtensionSettings = extensions;

      Cookies = {
        Allow = [
          "https://discord.com"
        ];
      };

      EnableTrackingProtection = {
        Exceptions = [ ];
      };
    };
  };

  shyfoxRepo = pkgs.fetchFromGitHub {
    owner = "Naezr";
    repo = "ShyFox";
    rev = "dd4836fb6f93267de6a51489d74d83d570f0280d";
    sha256 = "sha256-7H+DU4o3Ao8qAgcYDHVScR3pDSOpdETFsEMiErCQSA8=";
  };
in
{
  # Use Home Manager to manage LibreWolf
  programs.librewolf = {
    enable = true;
    package = librewolf-custom;
    settings = {
      "webgl.disabled" = false;
      "privacy.resistFingerprinting" = false;
      "privacy.clearOnShutdown.history" = false;
      "privacy.clearOnShutdown.cache" = false;
      "privacy.clearOnShutdown.cookies" = false;
      "privacy.clearOnShutdown.sessions" = false;
      "network.cookie.lifetimePolicy" = 0;

      # ShyFox settings
      "shyfox.remove.window.controls" = true;
    };
  };

  xdg.configFile."tridactyl/tridactylrc".source = ./tridactylrc;
  xdg.configFile."tridactyl/themes/tridactyl-theme.css".source = ./tridactyl-theme.css;

  home.file = {
    ".librewolf/gzqxztri.default/chrome".source = shyfoxRepo + "/chrome";
    ".librewolf/gzqxztri.default/user.js".source = shyfoxRepo + "/user.js";
  };
}
