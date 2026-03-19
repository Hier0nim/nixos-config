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
    systemd.tmpfiles.rules = [
      # Nixarr services keep their state under this shared directory.
      # Group write allows the service users (in the media group) to create subdirs.
      "d ${cfg.dataDir}/.state/nixarr 0770 root media - -"
      "Z ${cfg.dataDir}/.state/nixarr 0770 root media - -"
    ];

    sops = {
      secrets = {
        ${wgSecretName} = {
          sopsFile = config.custom.repoPath + "/secrets/${hostName}/vpn/transmission-wireguard.conf";
          format = "binary";
        };
        transmission_rpc_username = {
          sopsFile = config.custom.repoPath + "/secrets/${hostName}/transmission/credentials.yaml";
          key = "rpc-username";
        };
        transmission_rpc_password = {
          sopsFile = config.custom.repoPath + "/secrets/${hostName}/transmission/credentials.yaml";
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
