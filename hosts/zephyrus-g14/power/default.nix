{ lib, pkgs, ... }:
let
  radioPower = pkgs.writeShellApplication {
    name = "radio-power";
    runtimeInputs = with pkgs; [
      bluez
      coreutils
      iw
      util-linux
    ];
    text = builtins.readFile ./radio-power.sh;
  };
  command = lib.getExe radioPower;
  # Radio commands need privileges unavailable inside asusd's sandbox.
  powerChange = pkgs.writeShellScript "request-radio-power" ''
    exec ${pkgs.systemd}/bin/systemctl --no-block restart radio-power.service
  '';
in
{
  imports = [ (import ./radio-power.nix { inherit command; }) ];

  custom.hardware.asus = {
    enable = true;
    asusdConfigPath = pkgs.writeText "asusd.ron" (
      lib.replaceStrings [ "@radioPowerCommand@" ] [ (toString powerChange) ] (
        builtins.readFile ./asusd.ron
      )
    );
  };

  hardware.nvidia.dynamicBoost.enable = true;

  services = {
    # asusd owns the AC/battery profiles and CPU EPP settings.
    power-profiles-daemon.enable = lib.mkForce false;
    # nixos-hardware otherwise enables TLP when power-profiles-daemon is off.
    tlp.enable = lib.mkForce false;
    supergfxd.enable = lib.mkForce false;
    # Cardwire reads AC/battery state from UPower.
    upower.enable = true;

    cardwired = {
      enable = true;
      settings = {
        # Block new dGPU access on battery; restore Hybrid on AC.
        battery_auto_switch = true;
        battery_auto_switch_mode = "hybrid";
        external_display_auto_switch = true;
        # This host has one integrated GPU and one NVIDIA GPU.
        experimental_nvidia_block = true;
      };
    };
  };
}
