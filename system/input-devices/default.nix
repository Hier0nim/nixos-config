{ lib, ... }:
{
  # Udev rules to allow access to the Lemokey mouse for changing settings
  services.udev.extraRules = ''
    # Lemokey G2
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d035", MODE="0660", GROUP="plugdev", TAG+="uaccess"

    # Ultra-Link 8K
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="362d", ATTRS{idProduct}=="d028", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';

  services.kanata = {
    enable = lib.mkDefault true;
    keyboards = {
      internalKeyboard = {
        devices = [
          "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
        ];
        configFile = ./kanata.kbd;
      };
    };
  };
}
