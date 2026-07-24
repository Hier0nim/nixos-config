{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-legion-y530-15ich
    inputs.microvm.nixosModules.host

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

  virtualisation.docker.package = pkgs.docker_29;

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
    # Advertise the terminal definition received from local Ghostty sessions over SSH.
    ghostty.terminfo
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

    workstation = {
      enable = true;
      ssh = {
        enable = true;
        hostPort = 2222;
        # Keep closed on the public firewall; use SSH ProxyJump through server-legion.
        openFirewall = false;
      };
    };

    services = {
      actual.enable = true;
      "enable-actual".enable = true;
      "remote-pi-relay".enable = true;
      forgejo.enable = true;
      forgejo.actions.runners.global = {
        vmName = "forgejo-runner";
        tapName = "tap-fj-runner";
        subnet = "10.203.0.0/30";
        hostAddress = "10.203.0.1";
        guestAddress = "10.203.0.2";
        macAddress = "02:00:00:30:00:02";
        egress.enable = true;
        resources = {
          memoryMiB = 9216;
          vcpus = 4;
          nixCacheMiB = 65536;
          qgroupReservePercent = 15;
          qgroupReserveMinMiB = 512;
          qgroupReserveFloorPercent = 25;
          qgroupLimitBudgetMiB = 98304;
          # Existing ext4 image; resize only through an explicit offline maintenance migration.
          dockerMiB = 8192;
        };
        runner = {
          name = "server-legion-forgejo-ci";
          tokenSecret = "forgejo_runner_token";
          tokenSopsFile = "secrets/server-legion/forgejo-runner.yaml";
          labels = [
            "forgejo-ci:docker://forgejo-runner-nix:${pkgs.nix.version}"
            "ubuntu-latest:docker://forgejo-runner-nix:${pkgs.nix.version}"
            "nix:docker://forgejo-runner-nix:${pkgs.nix.version}"
          ];
          imageNames = [ "nix" ];
          capacity = 1;
        };
      };
      sonarr.auth.bypassForApi = true;
      sonarr-anime.auth.bypassForApi = true;
      radarr.auth.bypassForApi = true;
      tdarr.enable = true;
      jellyfin.hardwareAcceleration = {
        enable = true;
        type = "nvenc";
        device = "/dev/nvidia0";
      };
      tdarr.hardwareAcceleration = {
        enable = true;
        type = "nvenc";
        device = "/dev/nvidia0";
      };
      immich.hardwareAcceleration = {
        enable = true;
        type = "nvenc";
        device = "/dev/nvidia0";
      };
    };

    backup.enable = true;
  };

  services.beszel.agent.enable = true;

  custom.wifi.networks = {
    pieczarkowo = {
      enable = true;
      autoconnect = true;
    };
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
