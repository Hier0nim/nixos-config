{ pkgs, ... }:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
    };
  };

  # Workaround: asus_wmi soft-blocks Bluetooth on boot and after resume.
  # This unblocks it so bluez can power the adapter on.
  systemd.services.bluetooth-unblock = {
    description = "Unblock Bluetooth rfkill after asus_wmi loads";
    after = [ "bluetooth.service" ];
    requires = [ "bluetooth.service" ];
    wantedBy = [ "bluetooth.service" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.kmod}/bin/rfkill unblock bluetooth";
  };

  # Also unblock after resume from suspend (asus_wmi re-blocks on resume).
  systemd.services.bluetooth-unblock-resume = {
    description = "Unblock Bluetooth rfkill after resume";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.kmod}/bin/rfkill unblock bluetooth";
  };
}
