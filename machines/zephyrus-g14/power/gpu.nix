{
  config,
  lib,
  pkgs,
  ...
}:
let
  useNvidiaSleepServices =
    config.hardware.nvidia.powerManagement.enable
    && !config.hardware.nvidia.powerManagement.kernelSuspendNotifier;
  nvidiaSleep = "${config.hardware.nvidia.package.out}/bin/nvidia-sleep.sh";
in
{
  hardware.nvidia = {
    dynamicBoost.enable = true;
    moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
  };

  services.cardwired = {
    enable = true;
    settings = {
      battery_auto_switch = true;
      external_display_auto_switch = true;
      experimental_nvidia_block = true;
    };
  };

  environment.etc."systemd/system-sleep/nvidia" = lib.mkIf useNvidiaSleepServices {
    source = "${config.hardware.nvidia.package.out}/lib/systemd/system-sleep/nvidia";
    mode = "0755";
  };

  systemd.services = {
    # Cardwire blocks NVIDIA access on battery.
    nvidia-powerd.unitConfig.ConditionACPower = true;
    nvidia-suspend-then-hibernate = lib.mkIf useNvidiaSleepServices {
      description = "NVIDIA suspend-then-hibernate preparation";
      before = [ "systemd-suspend-then-hibernate.service" ];
      requiredBy = [ "systemd-suspend-then-hibernate.service" ];
      path = [ pkgs.kbd ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${nvidiaSleep} suspend";
      };
    };
    nvidia-resume = lib.mkIf useNvidiaSleepServices {
      after = [ "systemd-suspend-then-hibernate.service" ];
      requiredBy = [ "systemd-suspend-then-hibernate.service" ];
    };
  };
}
