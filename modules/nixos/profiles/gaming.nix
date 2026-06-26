{ lib, ... }:
{
  imports = [
    ../gaming/controllers.nix
    ../gaming/gaming.nix
  ];

  custom.profiles.gaming.enable = lib.mkDefault true;
  custom.hardware.audio.support32Bit = lib.mkDefault true;
}
