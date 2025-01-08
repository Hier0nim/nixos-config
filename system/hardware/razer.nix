{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  hardware.openrazer.enable = mkDefault false;
  hardware.openrazer.devicesOffOnScreensaver = mkDefault false;
  hardware.openrazer.syncEffectsEnabled = mkDefault true;
  hardware.openrazer.batteryNotifier = mkDefault {
    enable = true;
    percentage = 30;
    frequency = 600;
  };

  environment.systemPackages = mkIf config.hardware.openrazer.enable [
    pkgs.polychromatic
  ];

  users.groups.plugdev = mkIf config.hardware.openrazer.enable {
    name = "plugdev";
    members = (config.hardware.openrazer.users or [ ]);
  };
}
