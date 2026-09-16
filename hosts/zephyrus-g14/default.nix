{
  lib,
  inputs,
  pkgs,
  ...
}:
let
  applyWifiPowersave = pkgs.writeShellScript "apply-wifi-powersave" ''
    if [ ! -r /sys/class/power_supply/ADP0/online ]; then
      exit 0
    fi

    if [ "$(< /sys/class/power_supply/ADP0/online)" -eq 1 ]; then
      power_save=off
    else
      power_save=on
    fi

    for wireless in /sys/class/net/*/wireless; do
      [ -e "$wireless" ] || continue
      interface="$(basename "$(dirname "$wireless")")"
      ${pkgs.iw}/bin/iw dev "$interface" set power_save "$power_save" || true
    done
  '';
  wifiPowersaveDispatcher = pkgs.writeShellScript "wifi-powersave-dispatcher" ''
    case "$2" in
      up | reapply)
        [ -d "/sys/class/net/$1/wireless" ] || exit 0
        exec ${applyWifiPowersave}
        ;;
    esac
  '';
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402x-nvidia
    inputs.disko.nixosModules.disko
    inputs.dank-greeter.nixosModules.default

    ./disko.nix
    ./hardware-configuration.nix

    ../../users/hieronim

    ../../modules/nixos/core
    ../../modules/nixos/profiles/laptop.nix
    ../../modules/nixos/profiles/workstation.nix
    ../../modules/nixos/profiles/gaming.nix
    ../../modules/nixos/profiles/dms.nix

    ../../modules/nixos/boot/plymouth.nix
    ../../modules/nixos/boot/usbcore.nix
    ../../modules/nixos/input-devices
    ../../modules/nixos/programs/neovim.nix
    ../../modules/nixos/services/winboat.nix
    ../../modules/nixos/hardware/asus.nix
    ../../modules/nixos/services/local-llama.nix

    # ../../modules/nixos/services/howdy.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      # Temporary downgrade: upstream linux-firmware 20260910 regresses AMD DMCUB; keep known-good 20260810.
      linux-firmware = prev.linux-firmware.overrideAttrs (_: rec {
        version = "20260810";
        src = final.fetchFromGitLab {
          owner = "kernel-firmware";
          repo = "linux-firmware";
          tag = version;
          hash = "sha256-P/fPpqaatp8Z2GV+I/OChiWGn6AhV+8w1RMFuX/LqHc=";
        };
      });
    })
  ];

  networking = {
    hostName = "zephyrus-g14";

    # Keep Wi-Fi responsive while plugged in, where it shares a radio with
    # Bluetooth audio. Re-enable power saving while running on battery.
    networkmanager = {
      wifi.powersave = lib.mkForce false;
      dispatcherScripts = [ { source = wifiPowersaveDispatcher; } ];
    };
  };

  systemd.services.wifi-powersave = {
    description = "Set Wi-Fi power saving based on AC power";
    after = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = applyWifiPowersave;
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}+="wifi-powersave.service"
  '';

  custom = {
    wifi.networks = {
      pieczarkowo = {
        enable = true;
        autoconnect = true;
      };
    };

    services.openssh.enable = false;
    hardware.asus = {
      enable = true;
      asusdConfigPath = ./asusd.ron;
    };
    services.localLlama.enable = false;
    programs.winboat.enable = false;
  };

  services.supergfxd.enable = lib.mkForce false;

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
  powerManagement.powertop.enable = true;

  environment.systemPackages = with pkgs; [
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
