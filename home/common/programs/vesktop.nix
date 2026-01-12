{
  programs.vesktop = {
    enable = true;

    settings = {
      arRPC = true;
      customTitleBar = true;
      staticTitle = true;
      discordBranch = "stable";
      enableSplashScreen = false;
      hardwareAcceleration = true;
      minimizeToTray = true;
    };

    vencord.settings = {
      autoUpdate = false;
      autoUpdateNotification = false;
      notifyAboutUpdates = false;
      useQuickCss = true;
      themeLinks = [
        "https://raw.githubusercontent.com/refact0r/midnight-discord/refs/heads/master/themes/flavors/midnight-vencord.theme.css"
      ];

      plugins = {
        ClearURLs.enabled = true;
        FixYoutubeEmbeds.enabled = true;
      };
    };
  };
}
