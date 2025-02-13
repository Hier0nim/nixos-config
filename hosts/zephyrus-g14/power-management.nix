{ config, pkgs, ... }:
{

  powerManagement.powertop.enable = true;
  environment.systemPackages =
    with pkgs;
    [
      btop
      s-tui
      stress
    ]
    ++ (with config.boot.kernelPackages; [ cpupower ]);

  services = {
    acpid.enable = true;

    thermald.enable = true;

    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 20;
      };
    };

    upower.enable = true;
  };
}
