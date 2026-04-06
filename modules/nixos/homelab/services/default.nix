{ lib, ... }:
{
  imports = lib.flatten [
    ./nixarr.nix
    ./tdarr.nix
    ./immich.nix
    ./copyparty.nix
    ./cockpit.nix
    ./actual.nix
    ./backup.nix
  ];
}
