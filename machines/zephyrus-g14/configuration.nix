{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./power ];

  config = {
    nixpkgs.config.allowUnfree = true;

    networking = {
      hostName = "zephyrus-g14";
      networkmanager.enable = true;
      firewall.enable = true;
    };

    time = {
      timeZone = "Europe/Warsaw";
    };
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings.LC_ALL = "en_US.UTF-8";
    };

    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
        # Ordinary builds do not need trusted-daemon privileges.
        trusted-users = lib.mkForce [ "root" ];
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://devenv.cachix.org"
          "https://noctalia.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        ];
      };
      # Retain rollback generations until migration and recovery are verified.
      gc.automatic = false;
    };

    boot = {
      kernelPackages = pkgs.linuxPackages_latest;
      initrd = {
        verbose = false;
        systemd.enable = true;
      };
      loader = {
        efi = {
          canTouchEfiVariables = true;
        };
        systemd-boot = {
          enable = true;
          editor = false;
          configurationLimit = 5;
        };
        timeout = 5;
      };
      tmp.cleanOnBoot = true;

      kernelParams = [
        "amdgpu.dcdebugmask=0x10"
        "quiet"
        "systemd.show_status=false"
        "rd.systemd.show_status=false"
        "udev.log_level=3"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
        "rd.udev.log_priority=3"
        "vt.global_cursor_default=0"
      ];
      kernelModules = [ "uinput" ];
      consoleLogLevel = 0;
      plymouth = {
        enable = true;
      };
    };

    hardware = {
      i2c.enable = true;
      uinput.enable = true;
      keyboard.qmk.enable = true;
      xone.enable = true;
      bluetooth = {
        enable = true;
        settings.General = {
          Experimental = true;
          FastConnectable = false;
        };
      };
      nvidia = {
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
    };

    security = {
      rtkit.enable = true;
      tpm2.enable = true;
    };

    programs = {
      zsh.enable = true;
      neovim = {
        enable = true;
        defaultEditor = true;
      };
      nix-ld = {
        enable = true;
        libraries = [ pkgs.stdenv.cc.cc ];
      };
      umbriel.enable = true;
      noctalia = {
        enable = true;
        recommendedServices.enable = true;
        systemd = {
          enable = true;
          target = "umbriel-session.target";
        };
      };
      dconf.enable = true;
      seahorse.enable = true;
      rog-control-center = {
        enable = true;
      };
      steam = {
        enable = true;
        gamescopeSession.enable = false;
        remotePlay.openFirewall = false;
        dedicatedServer.openFirewall = false;
      };
      gamescope = {
        enable = true;
        capSysNice = true;
      };
      gamemode.enable = true;
    };

    users = {
      mutableUsers = false;
      groups.uinput = { };
      # Passwords and primary administrative groups belong to Clan's users service.
      users.hieronim = {
        uid = 1000;
        home = "/home/hieronim";
        shell = pkgs.zsh;
        extraGroups = builtins.filter (group: builtins.hasAttr group config.users.groups) [
          "networkmanager"
          "audio"
          "video"
          "input"
          "dialout"
          "gamemode"
          "i2c"
        ];
      };
      users.root.shell = pkgs.zsh;
    };

    services = {
      # Clan's sshd instance enables the server and manages its host identity.
      openssh = {
        openFirewall = false;
        listenAddresses = [
          { addr = "127.0.0.1"; }
          { addr = "::1"; }
        ];
        settings = {
          PermitRootLogin = "prohibit-password";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
      fstrim.enable = true;
      hardware.bolt.enable = true;
      pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
      };
      printing.enable = true;
      gvfs.enable = true;
      udisks2.enable = true;
      gnome = {
        gnome-keyring.enable = true;
        localsearch.enable = true;
        tinysparql.enable = true;
      };
      samba-wsdd = {
        enable = true;
        discovery = true;
      };
      displayManager.noctalia-greeter = {
        enable = true;
        settings = {
          session.default = "Umbriel";
          user.default = "hieronim";
          cursor = {
            theme = "Bibata-Modern-Classic";
            size = 24;
            path = pkgs.bibata-cursors;
          };
        };
      };
      lact.enable = true;
      asus-px-keyboard-tool = {
        enable = true;
        settings.kb_brightness_cycle = {
          enabled = true;
          keycode = "KEY_PROG3";
        };
      };
      kanata = {
        enable = true;
        keyboards.internalKeyboard = {
          devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
          extraDefCfg = "process-unmapped-keys yes";
          configFile = ./kanata.kbd;
        };
      };
      udev.extraRules = ''
        KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"

        # Lemokey G2 and Ultra-Link 8K, for the active local user's configuration tools.
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d035", MODE="0660", GROUP="plugdev", TAG+="uaccess"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d028", MODE="0660", GROUP="plugdev", TAG+="uaccess"

        # 8BitDo Ultimate 2.4 GHz receiver.
        SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="3106", ATTR{manufacturer}=="8BitDo", RUN+="${pkgs.kmod}/bin/modprobe xpad", RUN+="${pkgs.runtimeShell} -c 'echo 2dc8 3106 > /sys/bus/usb/drivers/xpad/new_id'"

        # VIA keyboard configuration.
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="3255", TAG+="uaccess", MODE="0660"
      '';
    };

    systemd = {
      services = {
        kanata-internalKeyboard.serviceConfig.SupplementaryGroups = [
          "input"
          "uinput"
        ];
      };
      user.services.rog-control-center = {
        description = "rog-control-center";
        after = [ "umbriel-session.target" ];
        partOf = [ "umbriel-session.target" ];
        wantedBy = [ "umbriel-session.target" ];
        unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
        serviceConfig = {
          Type = "simple";
          ExecStartPre = "${lib.getExe' pkgs.glib.bin "gdbus"} wait --session --timeout 60 org.kde.StatusNotifierWatcher";
          ExecStart = "${lib.getExe' pkgs.asusctl "rog-control-center"} --autostart --background";
          Restart = "no";
          TimeoutStartSec = 65;
          TimeoutStopSec = 10;
        };
      };
    };

    environment = {
      localBinInPath = true;
      systemPackages = with pkgs; [
        git
        ddcutil
        lm_sensors
        libmtp
        mangohud
      ];
    };

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        inter
        source-serif
        noto-fonts
      ];
      fontconfig = {
        defaultFonts = {
          monospace = [ "JetBrainsMono Nerd Font Mono" ];
          sansSerif = [
            "Inter"
            "Noto Sans"
          ];
          serif = [
            "Source Serif 4"
            "Noto Serif"
          ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };

    # Existing installation data, not the release selected for packages.
    system.stateVersion = "25.05";
  };
}
