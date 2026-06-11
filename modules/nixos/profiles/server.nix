{ lib, ... }:
{
  imports = [
    ../services/openssh.nix
    ../services/zram.nix
  ];

  custom.hostRole = lib.mkDefault "server";
  custom.services.openssh.enable = lib.mkDefault true;
}
