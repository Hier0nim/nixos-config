{
  self,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    self.inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402x-nvidia
    self.inputs.asus-px-keyboard-tool.nixosModules.default
    ./power
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd = {
      verbose = false;
      systemd.enable = true;
    };
    loader = {
      efi.canTouchEfiVariables = true;
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
    plymouth.enable = true;
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

  security.tpm2.enable = true;
  users.groups.uinput = { };

  services = {
    fstrim.enable = true;
    hardware.bolt.enable = true;
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

      # Lemokey G2 and Ultra-Link 8K.
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d035", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d028", MODE="0660", GROUP="plugdev", TAG+="uaccess"

      # 8BitDo Ultimate 2.4 GHz receiver.
      SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="3106", ATTR{manufacturer}=="8BitDo", RUN+="${pkgs.kmod}/bin/modprobe xpad", RUN+="${pkgs.runtimeShell} -c 'echo 2dc8 3106 > /sys/bus/usb/drivers/xpad/new_id'"

      # VIA keyboard configuration.
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="3255", TAG+="uaccess", MODE="0660"
    '';
  };

  systemd.services.kanata-internalKeyboard.serviceConfig.SupplementaryGroups = [
    "input"
    "uinput"
  ];

  environment.systemPackages = with pkgs; [
    ddcutil
    lm_sensors
    libmtp
  ];
}
