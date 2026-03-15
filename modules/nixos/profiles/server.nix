{ lib, ... }:
{
  imports = [
    ../services/openssh.nix
    ../services/zram.nix
  ];

  custom.hostRole = lib.mkDefault "server";
}
