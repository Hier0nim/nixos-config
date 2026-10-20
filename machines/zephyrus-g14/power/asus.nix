# ASUS owns the laptop's AC/battery profiles and requests radio-policy updates.
{ lib, pkgs, ... }:
let
  # Radio commands need privileges unavailable inside asusd's sandbox.
  requestRadioPower = pkgs.writeShellScript "request-radio-power" ''
    exec ${pkgs.systemd}/bin/systemctl --no-block restart radio-power.service
  '';
  asusdConfig = pkgs.writeText "asusd.ron" (
    lib.replaceStrings [ "@radioPowerCommand@" ] [ (toString requestRadioPower) ] (
      builtins.readFile ./asusd.ron
    )
  );
in
{
  services = {
    asusd = {
      enable = true;
      asusdConfig.source = asusdConfig;
    };
    # Do not run competing AC/battery profile managers.
    power-profiles-daemon.enable = lib.mkForce false;
    tlp.enable = lib.mkForce false;
    supergfxd.enable = lib.mkForce false;
    upower.enable = true;
  };
}
