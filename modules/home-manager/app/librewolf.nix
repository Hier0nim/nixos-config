{ pkgs, userSettings, ... }:

{
  # Module installing librewolf as default browser
  home.packages = if (userSettings.wmType == "wayland") then [ pkgs.librewolf-wayland ]
                else [ pkgs.librewolf ];

  home.sessionVariables = if (userSettings.wmType == "wayland")
                            then { DEFAULT_BROWSER = "${pkgs.librewolf-wayland}/bin/librewolf";}
                          else
                            { DEFAULT_BROWSER = "${pkgs.librewolf}/bin/librewolf";};

  home.file.".librewolf/librewolf.overrides.cfg".text = ''
    defaultPref("font.name.serif.x-western","''+userSettings.font+''");

    defaultPref("font.size.variable.x-western",20);
    defaultPref("browser.toolbars.bookmarks.visibility","always");
    defaultPref("privacy.resisttFingerprinting.letterboxing", true);
    defaultPref("network.http.referer.XOriginPolicy",2);
    defaultPref("privacy.clearOnShutdown.history",false);
    defaultPref("privacy.clearOnShutdown.downloads",true);
    defaultPref("privacy.clearOnShutdown.cookies",false);
    defaultPref("gfx.webrender.software.opengl",false);
    defaultPref("webgl.disabled",true);
    pref("font.name.serif.x-western","''+userSettings.font+''");

    pref("font.size.variable.x-western",20);
    pref("browser.toolbars.bookmarks.visibility","never");
    pref("privacy.resisttFingerprinting.letterboxing", true);
    pref("network.http.referer.XOriginPolicy",2);
    pref("privacy.clearOnShutdown.history",false);
    pref("privacy.clearOnShutdown.downloads",true);
    pref("privacy.clearOnShutdown.cookies",false);
    pref("gfx.webrender.software.opengl",false);
    pref("webgl.disabled",true);
    '';

  xdg.mimeApps.defaultApplications = {
  "text/html" = "librewolf.desktop";
  "x-scheme-handler/http" = "librewolf.desktop";
  "x-scheme-handler/https" = "librewolf.desktop";
  "x-scheme-handler/about" = "librewolf.desktop";
  "x-scheme-handler/unknown" = "librewolf.desktop";
  };

}
