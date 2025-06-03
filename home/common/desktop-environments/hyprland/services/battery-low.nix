{ pkgs, ... }:
let
  batteryNotificationScript =
    pkgs.writeScriptBin "battery-low-notification"
      #nu
      ''
        #!${pkgs.nushell}/bin/nu

        let acpi = $"${pkgs.acpi}/bin/acpi"
        let notify_send = $"${pkgs.libnotify}/bin/notify-send"

        # Configurable battery low threshold (in percent)
        let threshold = 20

        # Get battery information
        let battery_output = (^$acpi | str trim | lines)

        # Exit early if no battery information was found
        if ($battery_output | is-empty) {
          print "No battery information available."
          exit 1
        }

        let battery_percentage = ($battery_output | split column " " | get column4 | str trim --char ',' | str trim --char '%').0

        if ($battery_percentage | is-empty) {
          print "No battery percentage found."
          exit 1
        }

        # Check if the battery is discharging before notifying
        if (not ($battery_output.0 | str contains "Discharging")) {
          print "Battery is not discharging (might be charging or full)."
          exit 0
        }

        # If battery percentage is less than or equal to the threshold, send a notification
        if ($battery_percentage != "") and (($battery_percentage | into int) <= 20) {
          ^$notify_send --urgency=critical "Low Battery" $"Battery at ($battery_percentage)%"
        } else {
          print "Battery OK."
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
