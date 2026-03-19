{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  immichService = cfg.services.immich;
  inherit (immichService.upstream) port;
  inherit (cfg.data) photos;
  immichFqdn = "${immichService.expose.subdomain}.${cfg.domain}";
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.photos.enable && immichService.enable) {
    services.immich = {
      enable = true;
      host = "127.0.0.1";
      openFirewall = false;
      inherit port;
      mediaLocation = photos;
      settings = {
        newVersionCheck.enabled = false;
        server.externalDomain = "https://${immichFqdn}";
      };
    };
  };
}
