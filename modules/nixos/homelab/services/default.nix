{ lib, ... }:
{
  imports = lib.flatten [
    ./nixflix.nix
    ./audiobookshelf
    ./beszel.nix
    ./copyparty.nix
    ./tdarr.nix
    ./remote-pi-relay.nix
    ./ttyd.nix
    ./immich.nix
    ./actual.nix
    ./enable-actual.nix
    ./backup.nix
    ./workstation.nix
  ];
}
