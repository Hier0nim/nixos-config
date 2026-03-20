{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-legion-y530-15ich

    ./disko.nix
    ./hardware-configuration.nix

    ../../users/hieronim

    ../../modules/nixos/core
    ../../modules/nixos/profiles/server.nix
    ../../modules/nixos/programs/neovim.nix
    ../../modules/nixos/homelab
  ];

  networking.hostName = "server-legion";
  networking.networkmanager.wifi.powersave = lib.mkForce false;

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  nixpkgs.overlays = [
    inputs.copyparty.overlays.default
  ];

  boot = {
    initrd = {
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

      timeout = 3;
    };

    tmp.cleanOnBoot = true;
    kernelPackages = pkgs.linuxPackages;
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    cifs-utils
    hdparm
    lm_sensors
    smartmontools
    nvme-cli
    usbutils
    pciutils
  ];

  homelab = {
    ssh.authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpMtn/1wYa2EhgfnGjU0ZHk4mBKz1Mr0SjioMu2h4Ya server-legion"
    ];

    enable = true;
    domain = "pieczarkowo.me";

    proxy.enable = true;

    profiles = {
      media.enable = true;
      photos.enable = true;
      files.enable = true;
      admin.enable = true;
    };

    services = {
      sonarr.auth.bypassForApi = true;
      radarr.auth.bypassForApi = true;
    };
  };

  custom.wifi.networks = {
    pieczarkowo = {
      enable = true;
      autoconnect = true;
    };
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
