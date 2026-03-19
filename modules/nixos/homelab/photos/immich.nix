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
      # Immich owns the photo library and can write to it.
      # Group 'media' gets read/traverse access so Copyparty can expose it read-only.
      "d ${cfg.photosDir} 0750 immich media - -"
      "Z ${cfg.photosDir} 0750 immich media - -"
    ];
  };
}
