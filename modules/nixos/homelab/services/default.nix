{ lib, ... }:
{
  imports = lib.flatten [
    ./nixflix.nix
    ./audiobookshelf.nix
    ./tdarr.nix
    ./immich.nix
    ./copyparty.nix
    ./cockpit.nix
    ./actual.nix
    ./enable-actual.nix
    ./backup.nix
  ];
}
