{ pkgs, ... }:
{
  imports = [

    # TODO: add disco support
    # ./disk-configuration.nix

    ./hardware-configuration.nix
    ./power-management.nix

    ./services/blueman.nix
    ./services/dbus.nix
    ./services/gnome-keyring.nix
    ./services/greetd.nix
    ./services/gvfs.nix
    ./services/pipewire.nix
    ./virtualisation/containers.nix
    ./virtualisation/docker.nix
    ./virtualisation/podman.nix

    ../config/fonts
    ../config/hardware/acpi_call
    ../config/hardware/bluetooth
    ../config/hardware/ssd
    ../config/window-managers/hyprland
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services = {
    fwupd.enable = true;
    hardware.bolt.enable = true;
  };

  # Asus specific services
  services.supergfxd.enable = true;
  services = {
    asusd = {
      enable = true;
      enableUserService = true;
    };
  };
  # programs.rog-control-center = {
  #   enable = true;
  #   autoStart = true;
  # };
}
