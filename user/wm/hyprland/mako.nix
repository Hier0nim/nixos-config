{
  config,
  pkgs,
  settings,
  ...
}:
{
  home.packages = [ pkgs.libnotify ];

  services.mako = {
    enable = true;
    font = "${settings.font}";
    margin = "0";
    padding = "10";
    borderSize = 2;
    borderRadius = 5;
    defaultTimeout = 10000;
    groupBy = "summary";
    iconPath = "${config.gtk.iconTheme.package}/share/icons/Papirus-Dark";
    backgroundColor = "#24273a";
    textColor = "#cad3f5";
    borderColor = "#f5bde6";
    progressColor = "#363a4f";
  };
}
