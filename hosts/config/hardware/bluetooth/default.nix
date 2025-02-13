{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bluez
    bluez-tools
  ];
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
    package = pkgs.bluez;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
    };
  };
}
