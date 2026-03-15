{ lib, ... }:
{
  imports = [
    ../hardware/bluetooth.nix
    ../hardware/suspend-and-hibernate.nix
    ../hardware/i2c.nix
    ../services/logind.nix
  ];

  custom.hostRole = lib.mkDefault "laptop";
}
