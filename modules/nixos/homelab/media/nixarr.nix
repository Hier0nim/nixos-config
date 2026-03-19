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
    users = {
      users = {
        bazarr.extraGroups = [ "media" ];
        jellyseerr.extraGroups = [ "media" ];
        prowlarr.extraGroups = [ "media" ];
        radarr.extraGroups = [ "media" ];
        readarr.extraGroups = [ "media" ];
        "readarr-audiobook".extraGroups = [ "media" ];
        sonarr.extraGroups = [ "media" ];
      };
    };

    systemd.tmpfiles.rules = [
      # Nixarr services keep their state under this shared directory.
      # Group write allows the service users (in the media group) to create subdirs.
      "d ${cfg.dataDir}/.state/nixarr 0770 root media - -"
      "Z ${cfg.dataDir}/.state/nixarr 0770 root media - -"

      "d ${cfg.dataDir}/.state/nixarr/prowlarr 0750 prowlarr media - -"
      "Z ${cfg.dataDir}/.state/nixarr/prowlarr 0750 prowlarr media - -"

      "d ${cfg.dataDir}/.state/nixarr/radarr 0750 radarr media - -"
      "Z ${cfg.dataDir}/.state/nixarr/radarr 0750 radarr media - -"

      "d ${cfg.dataDir}/.state/nixarr/sonarr 0750 sonarr media - -"
      "Z ${cfg.dataDir}/.state/nixarr/sonarr 0750 sonarr media - -"

      "d ${cfg.dataDir}/.state/nixarr/bazarr 0750 bazarr media - -"
      "Z ${cfg.dataDir}/.state/nixarr/bazarr 0750 bazarr media - -"

      "d ${cfg.dataDir}/.state/nixarr/jellyseerr 0750 jellyseerr media - -"
      "Z ${cfg.dataDir}/.state/nixarr/jellyseerr 0750 jellyseerr media - -"

      "d ${cfg.dataDir}/.state/nixarr/readarr 0750 readarr media - -"
      "Z ${cfg.dataDir}/.state/nixarr/readarr 0750 readarr media - -"

      "d ${cfg.dataDir}/.state/nixarr/readarr-audiobook 0750 readarr-audiobook media - -"
      "Z ${cfg.dataDir}/.state/nixarr/readarr-audiobook 0750 readarr-audiobook media - -"
    ];

    sops = {
      secrets = {
        ${wgSecretName} = {
          sopsFile = "${config.custom.repoPath}/secrets/${hostName}/vpn/transmission-wireguard.conf";
          format = "binary";
        };
        transmission_rpc_username = {
          sopsFile = "${config.custom.repoPath}/secrets/${hostName}/transmission/credentials.yaml";
          key = "rpc-username";
        };
        transmission_rpc_password = {
          sopsFile = "${config.custom.repoPath}/secrets/${hostName}/transmission/credentials.yaml";
          key = "rpc-password";
        };
      };

      templates.transmission_credentials_json = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          {
            "rpc-authentication-required": true,
            "rpc-username": "${config.sops.placeholder.transmission_rpc_username}",
            "rpc-password": "${config.sops.placeholder.transmission_rpc_password}"
          }
        '';
      };
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
        credentialsFile = config.sops.templates.transmission_credentials_json.path;

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
