{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  cockpitFqdn = "${cfg.services.cockpit.expose.subdomain}.${cfg.domain}";
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.admin.enable && cfg.services.cockpit.enable) {
    homelab.services.cockpit.expose.reverseProxyExtraConfig = lib.mkDefault ''
      header_up Host {host}
      header_up X-Real-IP {remote_host}
      header_up X-Forwarded-For {remote_host}
      header_up X-Forwarded-Proto {scheme}
    '';

    services.cockpit = {
      enable = true;
      settings.WebService = {
        Origins = lib.mkForce "https://${cockpitFqdn}";
      };
    };

  };
}
