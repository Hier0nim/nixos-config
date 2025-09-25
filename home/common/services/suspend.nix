{
  pkgs,
  ...
}:
let
  script = pkgs.writeShellScriptBin "lowbatt" ''
    function notify() {
      ${pkgs.libnotify}/bin/notify-send \
        --urgency=$1 \
        --hint=int:transient:1 \
        --icon=computer \
        "$2" "$3"
    }


    battery_capacity=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/BAT0/capacity)
    battery_status=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/BAT0/status)

    if [[ $battery_status = "Discharging" ]]; then
        if [[ $battery_capacity -le 25 ]]; then
        notify "critical" "Battery Low" "You should probably plug-in."
        fi

        if [[ $battery_capacity -le 10 ]]; then
        notify "critical" "Battery Low" "Battery Low - 10%."
        fi

        if [[ $battery_capacity -le 5 ]]; then
          notify "critical" "Battery Critically Low" "Computer will hibernate in 60 seconds."

          ${pkgs.busybox}/bin/sleep 60

          battery_status=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/BAT0/status)

          if [[ $battery_status = "Discharging" ]]; then
              systemctl suspend
          fi
        fi
    fi
  '';

in
{
  systemd.user.timers."lowbatt" = {
    Unit = {
      Description = "check battery level";
      Requires = "lowbatt.service";
    };

    Timer = {
      OnCalendar = "*-*-* *:*:00";
      Unit = "lowbatt.service";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services."lowbatt" = {
    Unit = {
      Description = "battery level notifier";
    };

    Service = {
      PassEnvironment = "DISPLAY";
      ExecStart = "${script}/bin/lowbatt";
    };
  };
}
