{ config, lib, ... }:
let
  cfg = config.homelab;
  forgejoCfg = cfg.services.forgejo;
  actionsCfg = forgejoCfg.actions;
in
{
  config = lib.mkIf (cfg.enable && forgejoCfg.enable && actionsCfg.enable) {
    sops.secrets.${actionsCfg.tokenSecret}.sopsFile =
      config.custom.repoPath + "/${actionsCfg.tokenSopsFile}";

    sops.templates."forgejo-runner-token.env" = {
      content = "TOKEN=${config.sops.placeholder.${actionsCfg.tokenSecret}}\n";
      owner = "gitea-runner";
      group = "gitea-runner";
      mode = "0400";
      restartUnits = [ "gitea-runner-global.service" ];
    };
  };
}
