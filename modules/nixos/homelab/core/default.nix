{ lib, ... }:
{
  imports = lib.flatten [
    ./storage.nix
    ./state.nix
    ./permissions.nix
    ./ssh.nix
    ./caddy.nix
  ];
}
