# Apply the current power-source policy without toggling either radio.
exec 9>/run/lock/radio-power.lock
flock 9

wifi=on
usb=auto
fast_connect=off

# Any online external supply counts, including USB-C chargers.
for supply in /sys/class/power_supply/*; do
  [[ -r "$supply/type" && -r "$supply/online" ]] || continue
  [[ "$(< "$supply/type")" != Battery ]] || continue
  if [[ "$(< "$supply/online")" == 1 ]]; then
    wifi=off
    usb=on
    fast_connect=on
    break
  fi
done

for wireless in /sys/class/net/*/wireless; do
  [[ -d "$wireless" ]] || continue
  interface=${wireless%/wireless}
  interface=${interface##*/}
  if ! iw dev "$interface" set power_save "$wifi"; then
    echo "radio-power: could not set Wi-Fi power saving for $interface" >&2
  fi
done

for adapter in /sys/class/bluetooth/hci*; do
  name=${adapter##*/}
  [[ "$name" =~ ^hci[0-9]+$ ]] || continue
  [[ -e "$adapter/device" ]] || continue

  # Find the USB device, not its interface or upstream hub.
  device=$(readlink -f "$adapter/device")
  while [[ "$device" != / && ! -e "$device/idVendor" ]]; do
    device=${device%/*}
    device=${device:-/}
  done
  if [[ -w "$device/power/control" ]]; then
    if ! printf '%s\n' "$usb" > "$device/power/control"; then
      echo "radio-power: could not set USB power control for $name" >&2
    fi
  fi

  # A blocked or unsupported controller must not stall the other hooks.
  if ! timeout 3 btmgmt --index "${name#hci}" fast-conn "$fast_connect"; then
    echo "radio-power: could not set fast-connect mode for $name" >&2
  fi
done
