{
  # Enable the uinput module
  boot.kernelModules = ["uinput"];

  # Enable uinput
  hardware.uinput.enable = true;

  # Set up udev rules for uinput
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"

    # Lemokey G2
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d035", MODE="0660", GROUP="plugdev", TAG+="uaccess"

    # Ultra-Link 8K
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d028", MODE="0660", GROUP="plugdev", TAG+="uaccess"

    # 8bitdo
    ACTION=="add", ATTRS{idVendor}=="2dc8", ATTRS{idProduct}=="3106", RUN+="/sbin/modprobe xpad", RUN+="/bin/sh -c 'echo 2dc8 3106 > /sys/bus/usb/drivers/xpad/new_id'"b", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d028", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';

  # Ensure the uinput group exists
  users.groups.uinput = {};

  # Add the Kanata service user to necessary groups
  systemd.services.kanata-internalKeyboard.serviceConfig = {
    SupplementaryGroups = [
      "input"
      "uinput"
    ];
  };

  services.kanata = {
    enable = true;
    keyboards = {
      internalKeyboard = {
        devices = [
          # Replace the paths below with the appropriate device paths for your setup.
          # Use `ls /dev/input/by-path/` to find your keyboard devices.
          "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
        ];
        extraDefCfg = "process-unmapped-keys yes";

        configFile = ./kanata.kbd;
      };
    };
  };
}
