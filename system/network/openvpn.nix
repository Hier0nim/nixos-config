{ pkgs, ... }:
{
  programs.openvpn3.enable = true;
  services.dbus.packages = [ pkgs.openvpn3 ];
}
