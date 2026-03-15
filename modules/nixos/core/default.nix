{ lib, ... }:
{
  imports = lib.flatten [
    ../options
    ./hardware
    ./nix
    ./security
    ./services
    ./system
    ./shell
  ];
}
