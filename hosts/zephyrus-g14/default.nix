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

    ./disko-config.nix
    ./hardware-configuration.nix

    ../common/core
    ../users/hieronim

    ../common/optional/hardware/bluetooth.nix
    ../common/optional/hardware/suspend-and-hibernate.nix
    ../common/optional/hardware/i2c.nix
    ../common/optional/input-devices/default.nix
    ../common/optional/programs/neovim.nix
    ../common/optional/services/openssh.nix
    ../common/optional/services/openvpn3.nix
    ../common/optional/services/gnome-keyring.nix
    ../common/optional/services/printing.nix
    ../common/optional/services/logind.nix
    # ../common/optional/services/howdy.nix
    ../common/optional/services/winboat.nix
    ../common/optional/services/openssh.nix
    ../common/optional/services/wsdd.nix
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
    kernelPackages = pkgs.linuxPackages_latest;
  };
  hardware.nvidia.open = false;

  services = {
    # ASUS specific software. This also installs asusctl.
    asusd = {
      enable = true;
      enableUserService = true;
      asusdConfig.source = ./asusd.ron;
    };
    supergfxd.enable = lib.mkForce false;

    lact = {
      enable = true;
    };
  };

  programs.rog-control-center = {
    enable = true;
    autoStart = false;
  };

  systemd.user.services.rog-control-center = {
    description = "rog-control-center";

    after = [ "cosmic-session.target" ];
    partOf = [ "cosmic-session.target" ];
    wantedBy = [ "cosmic-session.target" ];

    startLimitBurst = 5;
    startLimitIntervalSec = 120;

    serviceConfig = {
      Type = "simple";
      ExecStart = lib.getExe' pkgs.asusctl "rog-control-center";
      Restart = "always";
      RestartSec = 1;
      TimeoutStopSec = 10;

      # Optional: keep your delay
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
    };
  };

  # services.auto-cpufreq = {
  #   enable = true;
  #   settings = {
  #     battery = {
  #       governor = "powersave";
  #       turbo = "never";
  #       platform_profile = "low-power";
  #     };
  #     charger = {
  #       governor = "performance";
  #       turbo = "auto";
  #       platform_profile = "balanced";
  #     };
  #   };
  # };
  # services.power-profiles-daemon.enable = false;

  # Optional: override defaults written to /etc/asus-px-keyboard-tool.conf
  # Note: Nix integers are decimal; convert hex (e.g. 0x7e) to decimal (126).
  services.asus-px-keyboard-tool = {
    enable = true;
    settings = {
      kb_brightness_cycle = {
        enabled = true;
        keycode = "KEY_PROG3";
      };
    };

  };
  powerManagement.powertop.enable = true;
  custom.programs.winboat.enable = false;

  environment.systemPackages = with pkgs; [
    stress-ng
    mprime
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
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
    ];
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
