{ ... }:
{
  imports = [
    ./state.nix
    ./actual.nix
    ./enable-actual.nix
    ./media.nix
    ./audiobookshelf.nix
    ./listenarr.nix
    ./beszel.nix
    ./forgejo.nix
    ./immich.nix
    ./workstation.nix
    ./ttyd.nix
    ./copyparty.nix
    ./proxy.nix
  ];
}
