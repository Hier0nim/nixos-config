{
  services.copyq = {
    enable = true;
    forceXWayland = true;
  };

  xdg.configFile."copyq/themes/kanagawa.ini" = {
    force = true;
    source = ./kanagawa-copyq.ini;
  };

  xdg.configFile."copyq/copyq.conf" = {
    force = true;
    source = ./copyq.conf;
  };
}
