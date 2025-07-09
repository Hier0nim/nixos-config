{ pkgs, ... }:
{
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
