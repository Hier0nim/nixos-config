{
  config,
  lib,
  pkgs,
  ...
}:
let
  nvidia = config.hardware.nvidia;
  useNvidiaSleepServices =
    nvidia.powerManagement.enable && !nvidia.powerManagement.kernelSuspendNotifier;
  nvidiaSleep = "${nvidia.package.out}/bin/nvidia-sleep.sh";
in
{
  # Remove inherited deep-sleep settings on s2idle-only hosts.
  options.boot.kernelParams = lib.mkOption {
    apply =
      params:
      if (config.systemd.sleep.settings.Sleep.MemorySleepMode or "") == "s2idle" then
        lib.filter (param: param != "mem_sleep_default=deep") params
      else
        params;
  };

  config = {
    systemd.sleep.settings.Sleep = {
      AllowSuspend = true;
      AllowHibernation = true;
      AllowSuspendThenHibernate = true;
      HibernateDelaySec = "10min";
      HibernateOnACPower = true;
    };

    systemd.services = lib.mkIf useNvidiaSleepServices {
      nvidia-suspend-then-hibernate = {
        description = "NVIDIA suspend-then-hibernate preparation";
        before = [ "systemd-suspend-then-hibernate.service" ];
        requiredBy = [ "systemd-suspend-then-hibernate.service" ];
        path = [ pkgs.kbd ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${nvidiaSleep} suspend";
        };
      };
      nvidia-resume = {
        after = [ "systemd-suspend-then-hibernate.service" ];
        requiredBy = [ "systemd-suspend-then-hibernate.service" ];
      };
    };

    # NixOS loads sleep hooks from /etc, not the NVIDIA package directory.
    environment.etc = lib.mkIf useNvidiaSleepServices {
      "systemd/system-sleep/nvidia" = {
        source = "${nvidia.package.out}/lib/systemd/system-sleep/nvidia";
        mode = "0755";
      };
    };
  };
}
