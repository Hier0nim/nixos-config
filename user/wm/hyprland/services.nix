{
  ...
}:
{
  services = {
    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };

    network-manager-applet.enable = true;
    blueman-applet.enable = true;
    cliphist.enable = true;
  };
}
