{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  inherit (cfg) data;
  inherit (config.networking) hostName;
  inherit (cfg.media.vpn) wgConfSecretName;
  jellyfinHwAccel = cfg.services.jellyfin.hardwareAcceleration;

  # sops paths for media secrets
  mediaSecretsFile = "${config.custom.repoPath}/secrets/${hostName}/media.yaml";
  mkMediaSecret = name: {
    sopsFile = mediaSecretsFile;
    inherit name;
    owner = "root";
    group = "keys";
    mode = "0440";
  };

  # nixflix _secret ref helper
  secretRef = name: { _secret = config.sops.secrets.${name}.path; };
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.media.enable) {
    # ===== SOPS secrets =====
    sops.secrets = {
      ${wgConfSecretName} = {
        sopsFile = "${config.custom.repoPath}/secrets/${hostName}/vpn/qbittorrent-wireguard.conf";
        format = "binary";
      };
      sonarr_api_key = mkMediaSecret "sonarr_api_key";
      sonarr_password = mkMediaSecret "sonarr_password";
      radarr_api_key = mkMediaSecret "radarr_api_key";
      radarr_password = mkMediaSecret "radarr_password";
      prowlarr_api_key = mkMediaSecret "prowlarr_api_key";
      prowlarr_password = mkMediaSecret "prowlarr_password";
      jellyfin_api_key = mkMediaSecret "jellyfin_api_key";
      seerr_api_key = mkMediaSecret "seerr_api_key";
      jellyfin_admin_password = mkMediaSecret "jellyfin_admin_password";
      qbittorrent_password = mkMediaSecret "qbittorrent_password";
      opensubtitles_username = mkMediaSecret "opensubtitles_username";
      opensubtitles_password = mkMediaSecret "opensubtitles_password";
    };

    # ===== nixflix global configuration =====
    nixflix = {
      enable = true;

      # Match existing homelab data paths
      mediaDir = data.media;
      downloadsDir = data.downloads;
      stateDir = "/var/lib/homelab/nixflix";

      # reverseProxy.domain is readOnly (derived from caddy/nginx) —
      # we don't need it since we use our own Caddy with expose=false on all services.

      # VPN — reuse exact same wireguard config secret
      vpn = {
        enable = true;
        wgConfFile = config.sops.secrets.${wgConfSecretName}.path;
      };

      # ===== Services =====

      # FlareSolverr — internal to Prowlarr, not proxied
      flaresolverr.enable = true;

      # Sonarr — declarative API config via nixflix
      sonarr = {
        inherit (cfg.services.sonarr) enable;
        config = {
          apiKey = secretRef "sonarr_api_key";
          hostConfig.password = secretRef "sonarr_password";
        };
        reverseProxy.expose = false;
      };

      # Radarr
      radarr = {
        inherit (cfg.services.radarr) enable;
        config = {
          apiKey = secretRef "radarr_api_key";
          hostConfig.password = secretRef "radarr_password";
        };
        reverseProxy.expose = false;
      };

      # Prowlarr
      prowlarr = {
        inherit (cfg.services.prowlarr) enable;
        config = {
          apiKey = secretRef "prowlarr_api_key";
          hostConfig.password = secretRef "prowlarr_password";
        };
        reverseProxy.expose = false;
      };

      # Jellyfin
      jellyfin = {
        inherit (cfg.services.jellyfin) enable;
        reverseProxy.expose = false;

        apiKey = secretRef "jellyfin_api_key";

        # Admin user (required by nixflix assertion + Seerr integration)
        users.admin = {
          policy.isAdministrator = true;
          password = secretRef "jellyfin_admin_password";
        };

        # Subtitle plugins replace Bazarr
        plugins = {
          "Open Subtitles" = {
            enable = true;
            config = {
              Username = config.sops.placeholder.opensubtitles_username;
              Password._secret = config.sops.secrets.opensubtitles_password.path;
            };
          };
          subbuzz.enable = true;
        };
      };

      # Jellyseerr → nixflix calls it 'seerr'
      seerr = {
        inherit (cfg.services.seerr) enable;
        package = lib.mkForce pkgs.jellyseerr; # nixpkgs name vs nixflix's pkgs.seerr
        apiKey = secretRef "seerr_api_key";

        # Jellyfin admin creds for Seerr library sync
        jellyfin.adminUsername = "admin";
        jellyfin.adminPassword = secretRef "jellyfin_admin_password";

        reverseProxy.expose = false;
      };

      # Recyclarr
      recyclarr = {
        inherit (cfg.services.recyclarr) enable;
      };

      # Torrent client: qBittorrent
      torrentClients.qbittorrent = {
        enable = true;

        vpn.enable = true;

        # WebUI port — match our Caddy proxy (pobieralnia:8080)
        webuiPort = 8080;

        # Download client password for Sonarr/Radarr/Prowlarr integration
        password = secretRef "qbittorrent_password";

        # Download/watch categories
        categories = {
          "tv-sonarr" = "${data.downloads}/torrent/tv";
          "radarr" = "${data.downloads}/torrent/movies";
        };

        reverseProxy.expose = false;
      };
    };

    # Jellyfin — ensure state dirs exist before systemd CHDIR/preStart.
    systemd = {
      tmpfiles.settings."20-homelab-jellyfin" = lib.mkIf cfg.services.jellyfin.enable (
        let
          jf = config.nixflix.jellyfin;
          dir = {
            mode = "0755";
            inherit (jf) user group;
          };
        in
        {
          "${jf.dataDir}".d = dir;
          "${jf.configDir}".d = dir;
          "${jf.cacheDir}".d = dir;
          "${jf.logDir}".d = dir;
          "${jf.system.metadataPath}".d = dir;
          "${jf.dataDir}/plugins".d = dir;
        }
      );

      services.jellyfin = {
        preStart = lib.mkIf cfg.services.jellyfin.enable (
          let
            jfDir = config.nixflix.jellyfin.dataDir;
            jfUser = config.nixflix.jellyfin.user;
            jfGroup = config.nixflix.jellyfin.group;
          in
          lib.mkBefore ''
            if [ -d ${jfDir} ]; then
              chown -R ${jfUser}:${jfGroup} ${jfDir}
            fi
          ''
        );

        serviceConfig = lib.mkIf (cfg.services.jellyfin.enable && jellyfinHwAccel.enable) {
          DeviceAllow = lib.mkAfter (
            [
              "${toString jellyfinHwAccel.device} rw"
            ]
            ++ lib.optionals (jellyfinHwAccel.type == "nvenc") [
              "/dev/nvidiactl rw"
              "/dev/nvidia-modeset rw"
              "/dev/nvidia-uvm rw"
              "/dev/nvidia-uvm-tools rw"
            ]
          );
        };
      };
    };

    users.users.${cfg.services.jellyfin.user}.extraGroups =
      lib.mkIf (cfg.services.jellyfin.enable && cfg.services.jellyfin.hardwareAcceleration.enable)
        [
          "render"
          "video"
        ];
  };
}
