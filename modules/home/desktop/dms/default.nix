{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  templatedSettings = pkgs.writeText "dms-settings.json" (
    builtins.replaceStrings [ "/home/hieronim/" ] [ "${config.home.homeDirectory}/" ] (
      builtins.readFile ./settings.json
    )
  );
in
{
  imports = [
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
    inputs.danksearch.homeModules.dsearch
    ./niri.nix
  ];

  programs.dank-material-shell = {
    enable = true;
    enableSystemMonitoring = true;
    enableVPN = true;
    enableClipboardPaste = true;
    niri = {
      enableSpawn = true;
      enableKeybinds = false;
    };
  };

  programs.dsearch = {
    enable = true;
    package =
      inputs.danksearch.packages.${pkgs.stdenv.hostPlatform.system}.dsearch.overrideAttrs
        (old: {
          vendorHash = "sha256-scvZWbMHAhpYWCU0xZK1E6h6sAkoXegqI1iYS44fcCg=";
        });
  };

  dconf.enable = true;
  services.kdeconnect.enable = true;

  home = {
    activation.seedDankMaterialShellConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dms_config_dir="${config.xdg.configHome}/DankMaterialShell"

      if [ ! -e "$dms_config_dir/settings.json" ]; then
        run install -Dm0644 "${templatedSettings}" "$dms_config_dir/settings.json"
      fi

      if [ ! -e "$dms_config_dir/themes/kanagawa-paper/theme.json" ]; then
        run install -Dm0644 "${./themes/kanagawa-paper/theme.json}" "$dms_config_dir/themes/kanagawa-paper/theme.json"
      fi
    '';

    sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt6ct";
      QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    };

    packages = with pkgs; [
      adw-gtk3
      bibata-cursors
      inputs.niri-float-sticky.packages.${pkgs.stdenv.hostPlatform.system}.default
      kdePackages.qt6ct
      libsForQt5.qt5ct
      papirus-icon-theme
      swappy
      wl-clipboard
    ];
  };

  systemd.user.services.dms.Service.Environment = [
    "QT_QPA_PLATFORMTHEME=qt6ct"
    "QT_QPA_PLATFORMTHEME_QT6=qt6ct"
  ];
}
