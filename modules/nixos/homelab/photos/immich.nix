{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  immichFqdn = "${cfg.services.immich.subdomain}.${cfg.domain}";
in
{
  config = lib.mkIf (cfg.enable && cfg.photos.enable) {
    services.immich = {
      enable = true;
      host = "127.0.0.1";
      openFirewall = false;
      port = 2283;
      mediaLocation = cfg.photosDir;
      settings = {
        newVersionCheck.enabled = false;
        server.externalDomain = "https://${immichFqdn}";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.photosDir} 0750 immich immich - -"
    ];
  };
}
