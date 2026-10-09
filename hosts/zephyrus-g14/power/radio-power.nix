# command is the shared radio-policy executable.
{ command }:
{ lib, pkgs, ... }:
let
  dispatcher = pkgs.writeShellScript "radio-power-dispatcher" ''
    case "$2" in
      up | reapply) exec ${command} ;;
    esac
  '';
in
{
  # NetworkManager must not overwrite the runtime policy.
  networking.networkmanager = {
    wifi.powersave = lib.mkForce null;
    settings.connection."wifi.powersave" = 1;
    dispatcherScripts = [ { source = dispatcher; } ];
  };

  # The script controls autosuspend through each adapter's power/control file.
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=1
  '';

  # Blanket tuning would override the radio policy.
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

  # Queue work outside udev; repeated events must also reapply the policy.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="bluetooth", KERNEL=="hci[0-9]*", RUN+="${pkgs.systemd}/bin/systemctl --no-block restart radio-power.service"
  '';
}
