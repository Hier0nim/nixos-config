{ pkgs, ... }:
{
  services.udev.extraRules = ''
    # 8bitdo ultimate 2.4
    SUBSYSTEM=="usb", ATTR{idVendor}=="2dc8", ATTR{idProduct}=="3106", ATTR{manufacturer}=="8BitDo", RUN+="/sbin/modprobe xpad", RUN+="/bin/sh -c 'echo 2dc8 3106 > /sys/bus/usb/drivers/xpad/new_id'"

    # Logitech Driving Force GT Racing Wheel
    ATTRS{idProduct}=="c29a", RUN+="/bin/sh -c 'cd %S%p; chmod 666 alternate_modes combine_pedals range gain autocenter spring_level damper_level friction_level ffb_leds peak_ffb_level'"
  '';

  environment.systemPackages = [ pkgs.oversteer ];
  hardware.new-lg4ff.enable = true;
}
