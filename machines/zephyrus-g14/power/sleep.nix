# Firmware sleep mode, lid behavior, and timed hibernation policy.
{ lib, ... }:
{
  # nixos-hardware adds deep sleep, but this laptop's firmware supports s2idle only.
  options.boot.kernelParams = lib.mkOption {
    apply = params: lib.filter (param: param != "mem_sleep_default=deep") params;
  };

  config = {
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend-then-hibernate";
      HandleLidSwitchDocked = "ignore";
    };

    systemd.sleep.settings.Sleep = {
      MemorySleepMode = "s2idle";
      AllowSuspend = true;
      AllowHibernation = true;
      AllowSuspendThenHibernate = true;
      HibernateDelaySec = "10min";
      HibernateOnACPower = true;
    };
  };
}
