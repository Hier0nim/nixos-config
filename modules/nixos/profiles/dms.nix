{ lib, ... }:
{
  imports = [
    ../desktop/dms.nix
  ];

  custom.desktop.dms.enable = lib.mkDefault true;
}
