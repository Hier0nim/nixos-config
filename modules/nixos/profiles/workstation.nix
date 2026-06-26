{ lib, ... }:
{
  imports = [
    ../fonts
    ../services/gnome-keyring.nix
    ../services/gvfs.nix
    ../services/printing.nix
    ../services/openssh.nix
    ../services/wsdd.nix
  ];

  custom.services.openssh.enable = lib.mkDefault true;
  custom.hardware.audio.enable = lib.mkDefault true;
}
