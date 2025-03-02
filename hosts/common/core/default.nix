{lib, ...}: {
  imports = lib.flatten [
    ./hardware
    ./nix
    ./security
    ./services
    ./system
    ./shell
  ];
}
