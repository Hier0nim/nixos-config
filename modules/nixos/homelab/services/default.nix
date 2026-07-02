{ lib, ... }:
{
  imports = lib.flatten [
    ./nixflix.nix
    ./audiobookshelf.nix
    ./beszel.nix
    ./copyparty.nix
    ./tdarr.nix
    ./ttyd.nix
    ./immich.nix
    ./actual.nix
    ./enable-actual.nix
    ./backup.nix
  ];
}
