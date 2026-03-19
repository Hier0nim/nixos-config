{ lib, ... }:
{
  imports = lib.flatten [
    ./options.nix
    ./directories.nix
    ./ssh.nix
    ./backup.nix
    ./proxy
    ./media
    ./photos
    ./files
    ./monitoring
  ];
}
