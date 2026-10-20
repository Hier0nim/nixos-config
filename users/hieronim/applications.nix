{ inputs, pkgs, ... }:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  discordTheme = "https://vokinn.github.io/kanagawa-discord/dist/kanagawa-wave.theme.css";
in
{
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
    inputs.nix-index-database.homeModules.default
    inputs.pi-config.homeManagerModules.default
  ];

  programs.nix-index-database.comma.enable = true;

  home.packages = with pkgs; [
    # Personal editor; plain Neovim remains available in the system profile.
    inputs.nvim.packages.${stdenv.hostPlatform.system}.default
    teams-for-linux
    proton-pass
    remmina
    qbittorrent
    proton-vpn
    protonmail-desktop
    libreoffice-stable
    jellyfin-desktop
    via
    (heroic.override {
      extraPkgs = pkgs: [
        pkgs.gamescope
        pkgs.gamemode
      ];
    })
    prismlauncher
    (import inputs.creamlinux-installer { inherit pkgs; })
  ];

  programs.equibop = {
    enable = true;
    settings = {
      arRPC = true;
      arRPCProcessScanning = false;
      nativeTitleBar = false;
      staticTitle = true;
      discordBranch = "stable";
      enableSplashScreen = false;
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
      themeLinks = [ discordTheme ];
      enabledThemeLinks = [ discordTheme ];
      plugins = {
        ClearURLs.enabled = true;
        FixYoutubeEmbeds.enabled = true;
      };
    };
  };

  programs.obs-studio = {
    enable = true;
    plugins = [ pkgs.obs-studio-plugins.obs-backgroundremoval ];
  };

  programs.spicetify = {
    enable = true;
    enabledExtensions = with spicePkgs.extensions; [
      adblock
      shuffle
    ];
    enabledCustomApps = with spicePkgs.apps; [
      newReleases
      ncsVisualizer
    ];
    enabledSnippets = [ spicePkgs.snippets.pointer ];
    theme = spicePkgs.themes.sleek;
    colorScheme = "BladeRunner";
  };

  home.file.".ideavimrc".source = ./files/ideavimrc;

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/mailto" = [ "proton-mail.desktop" ];
    "x-scheme-handler/spotify" = [ "spotify.desktop" ];
    "x-scheme-handler/discord" = [ "equibop.desktop" ];
  };

  xdg.configFile."gamescope/scripts/gamescope-explicit-sync-off.lua" = {
    force = true;
    source = ./files/gamescope-explicit-sync-off.lua;
  };
}
