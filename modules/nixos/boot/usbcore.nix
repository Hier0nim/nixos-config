{
  pkgs,
  ...
}:

let
  powerSupply = "/sys/class/power_supply/ADP0/online";
  autosuspendPath = "/sys/module/usbcore/parameters/autosuspend";
  batteryDelay = "10";
  acDelay = "-1";

  usb-autosuspend-script = pkgs.writeShellScript "usb-autosuspend" ''
    set_all() {
      local delay="$1"
      # Set global default for new devices
      echo "$delay" > ${autosuspendPath}
      # Set per-device for existing devices
      for dev in /sys/bus/usb/devices/*/power/autosuspend; do
        [ -f "$dev" ] && echo "$delay" > "$dev"
      done
      # If disabling autosuspend (AC), also set control to 'on'
      if [ "$delay" = "-1" ]; then
        for dev in /sys/bus/usb/devices/*/power/control; do
          [ -f "$dev" ] && echo "on" > "$dev"
        done
      else
        for dev in /sys/bus/usb/devices/*/power/control; do
          [ -f "$dev" ] && echo "auto" > "$dev"
        done
      fi
    }
    update() {
      if [ "$(cat ${powerSupply})" = "1" ]; then
        set_all ${acDelay}
      else
        set_all ${batteryDelay}
      fi
    }
    update
    ${pkgs.inotify-tools}/bin/inotifywait -m -e modify ${powerSupply} | while read; do update; done
  '';
in
{
  # Remove the old static parameter; the service handles it dynamically
  boot.kernelParams = [ ];

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", RUN+="${usb-autosuspend-script}"
  '';

  systemd.services.usb-autosuspend = {
    description = "Dynamic USB autosuspend based on AC/battery status";
    wantedBy = [ "multi-user.target" ];
    after = [ "power-supply.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = usb-autosuspend-script;
      Restart = "always";
      RestartSec = "5";
    };
  };
}
