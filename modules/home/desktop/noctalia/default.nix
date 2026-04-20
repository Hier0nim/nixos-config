{
  pkgs,
  inputs,
  config,
  ...
}:
{
  home.activation = {
    noctaliaSettingsSeed =
      let
        noctaliaSettingsDir = config.xdg.configHome + "/noctalia";
        noctaliaSettingsFile = noctaliaSettingsDir + "/settings.json";
        seedFile = ./settings.json;
      in
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -e ${noctaliaSettingsFile} ]; then
          mkdir -p ${noctaliaSettingsDir}
          install -m 0644 ${seedFile} ${noctaliaSettingsFile}
        fi
      '';

    niriMonitorsBaseline =
      let
        niriConfigDir = config.xdg.configHome + "/niri";
        niriMonitorsFile = niriConfigDir + "/monitors.kdl";
      in
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${niriConfigDir}
        if [ ! -e ${niriMonitorsFile} ]; then
          : > ${niriMonitorsFile}
          chmod 0644 ${niriMonitorsFile}
        fi
      '';

    niriNoctaliaBaseline =
      let
        niriConfigDir = config.xdg.configHome + "/niri";
        niriNoctaliaFile = niriConfigDir + "/noctalia.kdl";
      in
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${niriConfigDir}
        if [ ! -e ${niriNoctaliaFile} ]; then
          : > ${niriNoctaliaFile}
          chmod 0644 ${niriNoctaliaFile}
        fi
      '';
  };

  imports = [
    inputs.noctalia.homeModules.default
    ./niri.nix
  ];

  programs.noctalia-shell.enable = true;
  dconf.enable = true;

  home.packages = with pkgs; [
    adw-gtk3
    qt6Packages.qt6ct
    wl-clipboard
  ];
}
