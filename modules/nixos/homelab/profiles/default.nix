{ lib, ... }:
{
  imports = lib.flatten [
    ./media-stack.nix
    ./photos-stack.nix
    ./files-stack.nix
    ./admin-stack.nix
  ];
}
