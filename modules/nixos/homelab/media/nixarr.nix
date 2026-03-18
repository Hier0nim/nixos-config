{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (config.networking) hostName;
  wgSecretName = cfg.media.vpn.wgConfSecretName;
in
{
  config = lib.mkIf (cfg.enable && cfg.media.enable) {
    sops.secrets.${wgSecretName} = {
      sopsFile = config.custom.repoPath + "/secrets/${hostName}/vpn/transmission-wireguard.conf";
      format = "binary";
    };
    sops.secrets.transmission_credentials = {
      sopsFile = config.custom.repoPath + "/secrets/${hostName}/transmission/credentials.yaml";
      format = "yaml";
    };

    nixarr = {
      enable = true;
      inherit (cfg) mediaDir;
      stateDir = "${cfg.dataDir}/.state/nixarr";
      mediaUsers = [ config.custom.username ];

      vpn = {
        enable = true;
        wgConf = config.sops.secrets.${wgSecretName}.path;
        accessibleFrom = [ "192.168.8.0/24" ];
      };

      prowlarr = {
        enable = true;
        openFirewall = false;
      };
      radarr = {
        enable = true;
        openFirewall = false;
      };
      sonarr = {
        enable = true;
        openFirewall = false;
      };
      bazarr = {
        enable = true;
        openFirewall = false;
      };
      transmission = {
        enable = true;
        openFirewall = false;
        vpn.enable = true;
        messageLevel = "info";
        credentialsFile = config.sops.secrets.transmission_credentials.path;

        extraSettings = {
          "download-dir" = cfg.downloadsDir;
          "trash-original-torrent-files" = true;
        };
      };
      jellyfin = {
        enable = true;
        openFirewall = false;
      };
      jellyseerr = {
        enable = true;
        openFirewall = false;
      };
      readarr = {
        enable = true;
        openFirewall = false;
      };
      "readarr-audiobook" = {
        enable = true;
        openFirewall = false;
      };
      audiobookshelf = {
        enable = true;
        openFirewall = false;
      };
      recyclarr = {
        enable = true;
        configFile = ./recyclarr.yaml;
      };
    };
  };
}
