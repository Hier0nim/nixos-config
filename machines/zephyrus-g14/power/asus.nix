{ lib, pkgs, ... }:
let
  # Run radio changes outside asusd's sandbox.
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
    # asusd manages power profiles.
    power-profiles-daemon.enable = lib.mkForce false;
    tlp.enable = lib.mkForce false;
    supergfxd.enable = lib.mkForce false;
    upower.enable = true;
  };
}
