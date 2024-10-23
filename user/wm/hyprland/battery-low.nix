{ pkgs, ... }:
let
  batteryNotificationScript =
    pkgs.writeScriptBin "battery-low-notification"
      #nu 
      ''
        #!${pkgs.nushell}/bin/nu

        let acpi = $"${pkgs.acpi}/bin/acpi"
        let notify_send = $"${pkgs.libnotify}/bin/notify-send"

        # Get the battery percentage
        let battery_output = (^$acpi | str trim)
        let battery_percentage = ($battery_output | lines | first | split column " " | get column4 | str trim --char ',' | str trim --char '%').0

        # Check if battery_percentage is not empty and less than or equal to 20%
        if ($battery_percentage != "") and (($battery_percentage | into int) <= 20) {
          ^$notify_send --urgency=critical "Low Battery" $"Battery at ($battery_percentage)%"
        } else {
          print "Failed to get battery percentage."
        }
      '';
in
{
  systemd.user.services."battery-low" = {
    Unit = {
      Description = "Notify user if battery is below 20%";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${batteryNotificationScript}/bin/battery-low-notification";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.timers."battery-low" = {
    Timer = {
      OnCalendar = "*:0/5"; # Runs every 5 minutes
      Unit = "battery-low.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
