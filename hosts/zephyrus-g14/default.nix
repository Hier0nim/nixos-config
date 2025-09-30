{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402x-nvidia
    inputs.chaotic.nixosModules.default
    inputs.disko.nixosModules.disko

    ./disko-config.nix
    ./hardware-configuration.nix

    ../common/core
    ../users/hieronim

    ../common/optional/hardware/bluetooth.nix
    ../common/optional/input-devices/default.nix
    ../common/optional/programs/neovim.nix
    ../common/optional/services/openssh.nix
    ../common/optional/services/openvpn3.nix
    ../common/optional/services/gnome-keyring.nix
    ../common/optional/services/printing.nix
    ../common/optional/services/logind.nix
    ../common/optional/boot/plymouth.nix
    ../common/optional/boot/usbcore.nix
    ../common/optional/desktop-environment/cosmic.nix
    ../common/optional/gaming
    ../common/optional/fonts
  ];

  networking.hostName = "zephyrus-g14";
  desktopManager.cosmicCustom.enable = true;

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

  # ASUS G14 Patched Kernel based off of Arch Linux Kernel
  boot.kernelPackages = pkgs.linuxPackages_cachyos-gcc;

  services = {
    # supergfxd controls GPU switching
    supergfxd.enable = true;

    # ASUS specific software. This also installs asusctl.
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
