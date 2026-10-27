{ lib, pkgs, ... }:
let
  radioPower = pkgs.writeShellApplication {
    name = "radio-power";
    runtimeInputs = with pkgs; [
      bluez
      coreutils
      iw
      util-linux
    ];
    text = builtins.readFile ./radio-power.sh;
  };
  command = lib.getExe radioPower;
  dispatcher = pkgs.writeShellScript "radio-power-dispatcher" ''
    case "$2" in
      up | reapply) exec ${command} ;;
    esac
  '';
in
{
  # Leave Wi-Fi power saving to the script.
  networking.networkmanager = {
    wifi.powersave = lib.mkForce null;
    settings.connection."wifi.powersave" = 1;
    dispatcherScripts = [ { source = dispatcher; } ];
  };

  # Allow the script to control Bluetooth autosuspend.
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=1
  '';

  # powertop would override the radio settings.
  powerManagement.powertop.enable = lib.mkForce false;
  powerManagement.resumeCommands = command;

  systemd.services.radio-power = {
    description = "Apply AC/battery radio power settings";
    after = [
      "NetworkManager.service"
      "bluetooth.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = command;
    };
  };

  systemd.services.bluetooth.postStart = command;

  # Run outside udev and reapply on each adapter event.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="bluetooth", KERNEL=="hci[0-9]*", RUN+="${pkgs.systemd}/bin/systemctl --no-block restart radio-power.service"
  '';
}
