{ pkgs, ... }:
{
  imports = [
    # TODO: add disco support
    # ./disk-configuration.nix

    ./hardware-configuration.nix
    ./power-management.nix

    ../users/hieronim
    ../users/gaming

    ../common/optional/hardware/bluetooth.nix
    ../common/optional/input-devices/default.nix
    ../common/optional/programs/neovim.nix
    ../common/optional/services/openssh.nix
    ../common/optional/services/openvpn3.nix
    ../common/optional/services/dbus.nix
    ../common/optional/services/gnome-keyring.nix
    ../common/optional/services/gvfs.nix
    ../common/optional/services/greetd.nix
    ../common/optional/boot/plymouth.nix
    ../common/optional/boot/usbcore.nix
    ../common/optional/desktop-environment/hyprland.nix
    ../common/optional/gaming
    ../common/optional/fonts
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot = {
    initrd = {
      verbose = false;
      systemd.enable = true;
    };

    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 5;
      };

      timeout = 0; # Spam space to enter the boot menu
    };

    tmp.cleanOnBoot = true;
  };

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

  programs.rog-control-center = {
    enable = true;
    autoStart = true;
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
