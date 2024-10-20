{ pkgs, ... }:
let
  # Define the battery notification script
  batteryNotificationScript = pkgs.writeShellScriptBin "battery-low-notification" ''
    acpi="${pkgs.acpi}/bin/acpi"
    notify_send="${pkgs.libnotify}/bin/notify-send"

    # Get the battery percentage (e.g., "85%")
    battery_output=$($acpi -b)
    battery_percentage=$(echo "$battery_output" | head -n1 | awk '{print $4}' | tr -d ',%')

    # Check if battery_percentage is not empty
    if [[ -n "$battery_percentage" ]]; then
      # Check if the battery percentage is less than or equal to 10%
      if (( $battery_percentage <= 10 )); then
        # Send a notification with urgency set to critical
        $notify_send --urgency=critical "Low Battery" "Battery at $battery_percentage%"
      fi
    else
      echo "Failed to get battery percentage."
    fi
  '';
in
{
  # Define the systemd user service without the .service suffix
  systemd.user.services."battery-low" = {
    Unit = {
      Description = "Notify user if battery is below 10%";
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

  # Define the systemd user timer without the .timer suffix
  systemd.user.timers."battery-low" = {
    Timer = {
      OnCalendar = "*:0/1"; # Runs every minute
      Unit = "battery-low.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
