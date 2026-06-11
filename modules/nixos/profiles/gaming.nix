{ lib, ... }:
{
  imports = [
    ../gaming/controllers.nix
    ../gaming/gaming.nix
  ];

  custom.profiles.gaming.enable = lib.mkDefault true;
}
