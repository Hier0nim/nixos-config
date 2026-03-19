{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  cockpitFqdn = "${cfg.services.cockpit.subdomain}.${cfg.domain}";
in
{
  config = lib.mkIf (cfg.enable && cfg.monitoring.enable && cfg.monitoring.cockpit.enable) {
    services.cockpit = {
      enable = true;
      settings.WebService = {
        Origins = lib.mkForce "https://${cockpitFqdn}";
      };
    };
  };
}
