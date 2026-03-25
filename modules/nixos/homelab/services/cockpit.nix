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
      upstream.scheme = lib.mkDefault "https";
    };

    services.cockpit = {
      enable = true;
      openFirewall = true;

      settings.WebService = {
        Origins = lib.mkForce ''
          https://192.168.8.2:9090
          https://server-legion:9090
        '';
        ProtocolHeader = "X-Forwarded-Proto";
        ForwardedForHeader = "X-Forwarded-For";
      };
    };
  };
}
