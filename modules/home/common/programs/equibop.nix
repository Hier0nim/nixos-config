let
  kanagawaTheme = "https://vokinn.github.io/kanagawa-discord/dist/kanagawa-wave.theme.css";
in
{
  programs.equibop = {
    enable = true;

    settings = {
      arRPC = true;
      # Keep RPC support without scanning running processes for games.
      arRPCProcessScanning = false;
      nativeTitleBar = false;
      staticTitle = true;
      discordBranch = "stable";
      enableSplashScreen = false;
      # Use the default GPU; do not request NVIDIA PRIME offloading.
      hardwareAcceleration = true;
      hardwareVideoAcceleration = true;
      minimizeToTray = true;
    };

    equicord.settings = {
      autoUpdate = false;
      autoUpdateNotification = false;
      notifyAboutUpdates = false;
      useQuickCss = true;
      enableOnlineThemes = true;
      themeLinks = [ kanagawaTheme ];
      # Registering a theme link does not enable it in Equicord.
      enabledThemeLinks = [ kanagawaTheme ];

      plugins = {
        ClearURLs.enabled = true;
        FixYoutubeEmbeds.enabled = true;
      };
    };
  };
}
