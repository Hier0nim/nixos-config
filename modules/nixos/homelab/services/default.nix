{ lib, ... }:
{
  imports = lib.flatten [
    ./backup.nix
    ./nixarr.nix
    ./immich.nix
    ./copyparty.nix
    ./cockpit.nix
  ];
}
