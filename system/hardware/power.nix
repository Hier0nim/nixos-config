{ pkgs, ... }:
{
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };

  services.throttled.enable = true;
  services.throttled.extraConfig = ''
    [GENERAL]
    Enabled: True
    Sysfs_Power_Path: /sys/class/power_supply/AC*/online
    Autoreload: True

    ## Settings to apply while connected to Battery power
    [BATTERY]
    Update_Rate_s: 30
    PL1_Tdp_W: 15
    PL1_Duration_s: 28
    PL2_Tdp_W: 20
    PL2_Duration_S: 0.002
    Trip_Temp_C: 80
    cTDP: 1
    Disable_BDPROCHOT: False

    ## Settings to apply while connected to AC power
    [AC]
    Update_Rate_s: 5
    PL1_Tdp_W: 25
    PL1_Duration_s: 28
    PL2_Tdp_W: 44
    PL2_Duration_S: 0.002
    Trip_Temp_C: 85
    cTDP: 2
    Disable_BDPROCHOT: False

    # All voltage values are expressed in mV and *MUST* be negative (i.e., undervolt)!
    [UNDERVOLT.BATTERY]
    CORE: -50
    GPU: -50
    CACHE: -50
    UNCORE: -30
    ANALOGIO: 0

    [UNDERVOLT.AC]
    CORE: -75
    GPU: -75
    CACHE: -75
    UNCORE: -50
    ANALOGIO: 0
  '';

  environment.systemPackages = with pkgs; [
    btop
    s-tui
    stress
  ];
}
