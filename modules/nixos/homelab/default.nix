{ lib, ... }:
{
  imports = lib.flatten [
    ./options.nix
    ./core
    ./services
    ./profiles
  ];
}
