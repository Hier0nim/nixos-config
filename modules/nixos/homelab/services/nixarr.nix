{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (cfg) data;
  inherit (config.networking) hostName;
  inherit (cfg.media.vpn) wgConfSecretName;

  mkAppdataRules =
    name:
    let
      svc = cfg.services.${name};
    in
    lib.optionals svc.enable [
      "d ${data.appdata}/${name} 0750 ${svc.user} ${svc.group} - -"
      "Z ${data.appdata}/${name} 0750 ${svc.user} ${svc.group} - -"
    ];
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.media.enable) {
    systemd.tmpfiles.rules = lib.concatLists [
      (mkAppdataRules "sonarr")
      (mkAppdataRules "radarr")
      (mkAppdataRules "prowlarr")
      (mkAppdataRules "bazarr")
      (mkAppdataRules "transmission")
      (mkAppdataRules "jellyfin")
      (mkAppdataRules "jellyseerr")
      (mkAppdataRules "audiobookshelf")
      (mkAppdataRules "readarr")
      (mkAppdataRules "readarr-audiobook")
    ];

    sops.secrets.${wgConfSecretName} = {
      sopsFile = "${config.custom.repoPath}/secrets/${hostName}/vpn/transmission-wireguard.conf";
      format = "binary";
    };

    services.flaresolverr = {
      enable = true;
      port = 8191;
      openFirewall = false;
    };

    nixarr = {
      enable = true;
      mediaDir = data.media;
      stateDir = data.appdata;
      mediaUsers = [ config.custom.username ];

      vpn = {
        enable = true;
        wgConf = config.sops.secrets.${wgConfSecretName}.path;
        accessibleFrom = [ "192.168.8.0/24" ];
      };

      prowlarr = {
        inherit (cfg.services.prowlarr) enable;
        openFirewall = false;
      };
      radarr = {
        inherit (cfg.services.radarr) enable;
        openFirewall = false;
      };
      sonarr = {
        inherit (cfg.services.sonarr) enable;
        openFirewall = false;
      };
      bazarr = {
        inherit (cfg.services.bazarr) enable;
        openFirewall = false;
      };
      transmission = {
        inherit (cfg.services.transmission) enable;
        openFirewall = false;
        vpn.enable = true;
        messageLevel = "info";

        extraSettings = {
          "download-dir" = "${data.downloads}/torrent/complete";
          "incomplete-dir" = "${data.downloads}/torrent/incomplete";
          "incomplete-dir-enabled" = true;
          "watch-dir" = "${data.downloads}/torrent/watch";
          "watch-dir-enabled" = true;
          "trash-original-torrent-files" = true;
          # Caddy handles auth; allow reverse-proxy hostnames.
          "rpc-host-whitelist-enabled" = false;
          "rpc-whitelist-enabled" = false;
          # Keep group write so Radarr/Sonarr can read/import.
          "umask" = 2;
        };
      };
      jellyfin = {
        inherit (cfg.services.jellyfin) enable;
        openFirewall = false;
      };
      jellyseerr = {
        inherit (cfg.services.jellyseerr) enable;
        openFirewall = false;
      };
      readarr = {
        inherit (cfg.services.readarr) enable;
        openFirewall = false;
      };
      "readarr-audiobook" = {
        inherit (cfg.services."readarr-audiobook") enable;
        openFirewall = false;
      };
      audiobookshelf = {
        inherit (cfg.services.audiobookshelf) enable;
        openFirewall = false;
      };
      recyclarr = {
        enable = true;
        configFile = ./recyclarr.yaml;
      };
    };
  };
}
