{
  config,
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
        pref("webgl.disabled", false);

        // Privacy-related preferences
        pref("privacy.clearOnShutdown.cache", false);
        pref("privacy.clearOnShutdown.cookies", false);
        pref("privacy.clearOnShutdown.history", false);
        pref("privacy.clearOnShutdown.sessions", false);
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
in
{
  # Use Home Manager to manage LibreWolf
  programs.librewolf = {
    enable = true;
    package = librewolf-custom;
  };
}
