{ lib, ... }:
{
  imports = lib.flatten [
    ./server.nix
    ./actions.nix
    ./runner-images.nix
    ./runner-secrets.nix
    ./runner-vm.nix
  ];
}
