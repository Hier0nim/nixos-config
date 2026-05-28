{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.admin.enable && cfg.services.cockpit.enable) {
    homelab.services.cockpit = {
      expose.enable = lib.mkDefault true;
      upstream.scheme = lib.mkDefault "https";
      auth.stripAuthorizationHeader = lib.mkDefault true;
    };

    services.cockpit = {
      enable = true;
      openFirewall = true;

      settings.WebService = {
        Origins = lib.mkForce ''
          https://192.168.8.2:9090
          https://server-legion:9090
          https://${cfg.services.cockpit.expose.subdomain}.${cfg.domain}
        '';
        ProtocolHeader = "X-Forwarded-Proto";
        ForwardedForHeader = "X-Forwarded-For";
      };
    };
  };
}
