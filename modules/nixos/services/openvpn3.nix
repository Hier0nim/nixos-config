{
  programs.openvpn3.enable = true;

  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
}
