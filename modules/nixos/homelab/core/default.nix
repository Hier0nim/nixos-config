{ lib, ... }:
{
  imports = lib.flatten [
    ./storage.nix
    ./permissions.nix
    ./ssh.nix
    ./caddy.nix
  ];
}
