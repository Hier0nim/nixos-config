{ config, lib, ... }:
let
  cfg = config.homelab;
  forgejoCfg = cfg.services.forgejo;
  enabledRunners = lib.filterAttrs (_: runner: runner.enable) forgejoCfg.actions.runners;
in
{
  config = lib.mkIf (cfg.enable && forgejoCfg.enable && enabledRunners != { }) {
    sops.secrets = lib.mapAttrs' (
      _: runner:
      lib.nameValuePair runner.runner.tokenSecret {
        sopsFile = config.custom.repoPath + "/${runner.runner.tokenSopsFile}";
        owner = "microvm";
        group = "kvm";
        mode = "0400";
        restartUnits = [ "microvm@${runner.vmName}.service" ];
      }
    ) enabledRunners;
  };
}
