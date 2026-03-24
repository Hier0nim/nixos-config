{ lib, ... }:
{
  imports = lib.flatten [
    ./options.nix
    ./meta.nix
    ./core
    ./services
    ./profiles
  ];
}
