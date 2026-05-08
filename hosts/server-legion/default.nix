{
  inputs,
  config,
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
    (import ../../overlays/llama-cpp-turboquant.nix)
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
      ai.enable = true;
    };

    services = {
      actual.enable = true;
      "enable-actual".enable = true;
      sonarr.auth.bypassForApi = true;
      radarr.auth.bypassForApi = true;
      tdarr.enable = true;
      "llama-cpp-agent" = {
        apiKeySecretName = "llama_cpp_agent_api_key";
        runtime = "native";
        defaultModel = "qwen";
        modelDir = "/var/lib/homelab/models/llm";

        models.qwen = {
          name = "Qwen 3.6 35B A3B";
          file = "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf";
          url = "https://huggingface.co/bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf?download=true";
          sha256 = "6f5c72e2cde7fb0a1584cc009cdb4513f26733740369d3e2df0e7d7247112d05";

          contextSize = 256000;
          gpuLayers = 99;
          cpuMoeLayers = 36;
          cacheTypeK = "turbo4";
          cacheTypeV = "turbo3";
          jinja = true;
        };

        expose = {
          enable = true;
          subdomain = "ai";
          api = {
            enable = true;
            subdomain = "ai-api";
          };
        };
      };
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

  sops = {
    secrets = {
      llama_cpp_agent_api_key = {
        sopsFile = ../../secrets/server-legion/llama-cpp-agent.yaml;
        key = "llama_cpp_agent_api_key";
        owner = "root";
        group = "keys";
        mode = "0440";
      };

      cloudflare_dns_api_token = {
        sopsFile = ../../secrets/server-legion/cloudflare.yaml;
        key = "cloudflare_dns_api_token";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    templates."acme-cloudflare.env" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.cloudflare_dns_api_token}
      '';
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = lib.mkDefault "hieronimdaniel@proton.me";

    certs."ai.pieczarkowo.me" = {
      extraDomainNames = [ "ai-api.pieczarkowo.me" ];
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."acme-cloudflare.env".path;
      group = "caddy";
    };
  };

  homelab.services."llama-cpp-agent".expose.tls = {
    certFile = "/var/lib/acme/ai.pieczarkowo.me/fullchain.pem";
    keyFile = "/var/lib/acme/ai.pieczarkowo.me/key.pem";
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
