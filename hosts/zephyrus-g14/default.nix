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
    inputs.dms.nixosModules.greeter

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

    # ../../modules/nixos/services/howdy.nix
  ];

  networking.hostName = "zephyrus-g14";

  nixpkgs.overlays = [
    (_final: _prev: {
      pi-coding-agent = inputs.nix-pi-agent.packages.${pkgs.system}.pi-agent;
    })
  ];

  custom.wifi.networks = {
    pieczarkowo = {
      enable = true;
      autoconnect = true;
    };
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

  services = {
    llama-cpp-swap = {
      enable = true;
      package = pkgs.llama-cpp.override { cudaSupport = true; };
      listenAddress = "127.0.0.1";
      port = 8080;
      openFirewall = false;
      modelDir = "/var/lib/llama-cpp/models";
      defaultModel = "qwen";
      idleStopMinutes = 5;

      models =
        let
          qwenModel = {
            name = "Qwen 3.6 35B A3B";
            file = "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf";
            url = "https://huggingface.co/bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf?download=true";
            sha256 = "6f5c72e2cde7fb0a1584cc009cdb4513f26733740369d3e2df0e7d7247112d05";

            gpuLayers = 99;
            cpuMoeLayers = 32;
            batchSize = 4096;
            ubatchSize = 512;
            cacheTypeK = "q8_0";
            cacheTypeV = "q8_0";
            temperature = 0.6;
            topP = 0.95;
            topK = 20;
            minP = 0.0;
            presencePenalty = 0.0;
            repeatPenalty = 1.0;
            jinja = true;
            extraArgs = [
              "--parallel"
              "1"
            ];
          };
        in
        {
          qwen = qwenModel // {
            contextSize = 131072;
          };
        };
    };

    # ASUS specific software. This also installs asusctl.
    asusd = {
      enable = true;
      asusdConfig.source = ./asusd.ron;
    };
    supergfxd.enable = lib.mkForce false;

    lact = {
      enable = true;
    };

    openssh.enable = lib.mkForce false;
    fail2ban.enable = lib.mkForce false;

    asus-px-keyboard-tool = {
      enable = true;
      settings = {
        kb_brightness_cycle = {
          enabled = true;
          keycode = "KEY_PROG3";
        };
      };
    };
  };

  programs.rog-control-center = {
    enable = true;
    autoStart = false;
  };

  systemd.user.services.rog-control-center = {
    description = "rog-control-center";

    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];

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
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
    ];
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
