{ ... }:
{
  imports = [
    ./state.nix
    ./identity
    ./certificates.nix
    ./actual
    ./media.nix
    ./audiobookshelf.nix
    ./listenarr
    ./beszel
    ./forgejo
    ./immich
    ./ttyd.nix
    ./copyparty
    ./proxy
  ];
}
