{
  lib,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402x-nvidia
    inputs.disko.nixosModules.disko
    inputs.umbriel.nixosModules.default
    inputs.noctalia.nixosModules.default
    inputs.noctalia-greeter.nixosModules.default

    ./disko.nix
    ./hardware-configuration.nix
    ./power

    ../../users/hieronim

    ../../modules/nixos/core
    ../../modules/nixos/profiles/laptop.nix
    ../../modules/nixos/profiles/workstation.nix
    ../../modules/nixos/profiles/gaming.nix
    ../../modules/nixos/profiles/umbriel-zephyrus.nix

    ../../modules/nixos/boot/plymouth.nix
    ../../modules/nixos/input-devices
    ../../modules/nixos/programs/neovim.nix
    ../../modules/nixos/services/winboat.nix
    ../../modules/nixos/hardware/asus.nix
    ../../modules/nixos/services/local-llama.nix

    # ../../modules/nixos/services/howdy.nix
  ];

  # Noctalia's official binary cache is trusted on this laptop only.
  nix.settings.substituters = lib.mkAfter [ "https://noctalia.cachix.org" ];
  nix.settings.trusted-public-keys = lib.mkAfter [
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];

  networking.hostName = "zephyrus-g14";

  custom = {
    wifi.networks = {
      pieczarkowo = {
        enable = true;
        autoconnect = true;
      };
    };

    services.openssh.enable = false;
    services.localLlama.enable = false;
    programs.winboat.enable = false;
  };

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
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "amdgpu.dcdebugmask=0x10"
    ];
  };
  hardware.nvidia = {
    open = false;
    prime = {
      sync.enable = lib.mkForce false;
      offload = {
        enable = lib.mkForce true;
        enableOffloadCmd = lib.mkForce true;
      };
    };

    powerManagement = {
      enable = lib.mkForce true;
      finegrained = lib.mkForce false;
    };
  };

  environment.systemPackages = with pkgs; [
    ddcutil
    stress-ng
    glmark2
    lm_sensors
    cifs-utils
  ];

  fileSystems."/mnt/NAS" = {
    device = "//192.168.8.1/nas";
    fsType = "cifs";
    options = [
      "guest"
      "iocharset=utf8"
      "vers=3.1.1"
      "uid=1000"
      "gid=100"
      "dir_mode=0755"
      "file_mode=0644"
      "nofail"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
    ];
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
