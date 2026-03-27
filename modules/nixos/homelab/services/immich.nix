{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  homelabMeta = import ../meta-data.nix;
  immichService = cfg.services.immich;
  inherit (immichService.upstream) port;
  inherit (cfg.data) photos;
  inherit (cfg.state) immichHot;
  immichFqdn = "${immichService.expose.subdomain}.${cfg.domain}";
  inherit (homelabMeta) immichBindTargets;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.photos.enable && immichService.enable) {
    homelab.services.immich.backup = {
      enable = lib.mkDefault true;
      paths = lib.mkDefault [
        "${cfg.data.photos}/library"
        "${cfg.data.photos}/backups"
        "${cfg.data.photos}/profile"
      ];
      exclude = lib.mkDefault [
        "${cfg.data.photos}/upload"
        "${cfg.data.photos}/thumbs"
        "${cfg.data.photos}/encoded-video"
      ];
    };

    services.immich = {
      enable = true;
      host = "127.0.0.1";
      openFirewall = false;
      inherit port;

      # Canonical Immich media root
      mediaLocation = photos;

      settings = {
        newVersionCheck.enabled = false;

        server = {
          externalDomain = "https://${immichFqdn}";
        };

        storageTemplate = {
          enabled = true;
          hashVerificationEnabled = true;
          template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
        };
      };
    };

    fileSystems = lib.listToAttrs (
      map (name: {
        name = "${photos}/${name}";
        value = {
          device = "${immichHot}/${name}";
          options = [
            "bind"
            "x-systemd.requires-mounts-for=${immichHot}/${name}"
          ];
        };
      }) immichBindTargets
    );
  };
}
