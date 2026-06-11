{
  pkgs,
  ...
}:
{
  services = {
    gvfs.enable = true;
    udisks2.enable = true;

    gnome = {
      localsearch.enable = true;
      tinysparql.enable = true;
    };
  };

  # MTP support for Android file transfer in Nautilus
  environment.systemPackages = [ pkgs.libmtp ];
}
