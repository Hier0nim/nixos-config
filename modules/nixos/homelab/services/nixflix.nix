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

  mediaSecretsFile = "${config.custom.repoPath}/secrets/${hostName}/media.yaml";
  mkMediaSecret = name: {
    sopsFile = mediaSecretsFile;
    inherit name;
    owner = "root";
    group = "keys";
    mode = "0440";
  };

  secretRef = name: { _secret = config.sops.secrets.${name}.path; };

  mediaSecretNames = [
    "sonarr_api_key"
    "sonarr_password"
    "radarr_api_key"
    "radarr_password"
    "prowlarr_api_key"
    "prowlarr_password"
    "jellyfin_api_key"
    "seerr_api_key"
    "jellyfin_admin_password"
    "qbittorrent_password"
    "opensubtitles_username"
    "opensubtitles_password"
    "opensubtitles_api_key"
    "sonarr_anime_api_key"
    "sonarr_anime_password"
    "jellyfin_pieczarkowo_password"
  ];

  arrServices = [
    "sonarr"
    "sonarr-anime"
    "radarr"
    "prowlarr"
  ];
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.media.enable) {
    sops.secrets = {
      ${wgConfSecretName} = {
        sopsFile = "${config.custom.repoPath}/secrets/${hostName}/vpn/qbittorrent-wireguard.conf";
        format = "binary";
      };
    }
    // lib.genAttrs mediaSecretNames mkMediaSecret;

    nixflix = {
      enable = true;
      mediaDir = data.media;
      downloadsDir = data.downloads;
      stateDir = "/var/lib/homelab/nixflix";
      vpn = {
        enable = true;
        wgConfFile = config.sops.secrets.${wgConfSecretName}.path;
      };

      theme.enable = true;
      theme.name = "overseerr";

      flaresolverr.enable = true;
    }
    // lib.genAttrs arrServices (
      name:
      let
        secretName = lib.replaceStrings [ "-" ] [ "_" ] name;
      in
      {
        inherit (cfg.services.${name}) enable;
        vpn.enable = true;
        config = {
          apiKey = secretRef "${secretName}_api_key";
          hostConfig.password = secretRef "${secretName}_password";
        }
        // lib.optionalAttrs (name == "prowlarr") {
          indexers = [
            { name = "YTS"; }
            {
              name = "Nyaa.si";
              tags = [ "anime" ];
            }
          ];
          applications = [
            {
              name = "Sonarr";
              implementationName = "Sonarr";
              apiKey = secretRef "sonarr_api_key";
            }
            {
              name = "Sonarr Anime";
              implementationName = "Sonarr";
              apiKey = secretRef "sonarr_anime_api_key";
            }
            {
              name = "Radarr";
              implementationName = "Radarr";
              apiKey = secretRef "radarr_api_key";
            }
          ];
        };
        reverseProxy.expose = false;
      }
    )
    // {
      jellyfin = {
        inherit (cfg.services.jellyfin) enable;
        reverseProxy.expose = false;
        apiKey = secretRef "jellyfin_api_key";

        users.admin = {
          policy.isAdministrator = true;
          password = secretRef "jellyfin_admin_password";
        };

        users.pieczarkowo = {
          password = secretRef "jellyfin_pieczarkowo_password";
          configuration = {
            displayMissingEpisodes = false;
            enableNextEpisodeAutoPlay = true;
          };
        };

        encoding = {
          hardwareAccelerationType = jellyfinHwAccel.type;
          enableHardwareEncoding = true;
          allowHevcEncoding = true;
          enableTonemapping = true;
          tonemappingAlgorithm = "bt2390";
          hardwareDecodingCodecs = [
            "h264"
            "hevc"
            "mpeg2video"
            "vc1"
            "vp8"
            "vp9"
            "av1"
          ];
        };

        libraries = {
          Movies = {
            paths = [ "${data.media}/movies" ];
            collectionType = "movies";
            enableRealtimeMonitor = true;
            saveLocalMetadata = false;
            subtitleDownloadLanguages = [
              "eng"
              "pol"
            ];
            saveSubtitlesWithMedia = true;
            requirePerfectSubtitleMatch = false;
            skipSubtitlesIfEmbeddedSubtitlesPresent = false;
          };
          "TV Shows" = {
            paths = [ "${data.media}/tv" ];
            collectionType = "tvshows";
            enableRealtimeMonitor = true;
            subtitleDownloadLanguages = [
              "eng"
              "pol"
            ];
            saveSubtitlesWithMedia = true;
            requirePerfectSubtitleMatch = false;
            skipSubtitlesIfEmbeddedSubtitlesPresent = false;
          };
          Anime = {
            paths = [ "${data.media}/anime" ];
            collectionType = "tvshows";
            enableRealtimeMonitor = true;
            subtitleDownloadLanguages = [
              "eng"
              "pol"
            ];
            saveSubtitlesWithMedia = true;
            requirePerfectSubtitleMatch = false;
            skipSubtitlesIfEmbeddedSubtitlesPresent = false;
          };
          Audiobooks = {
            paths = [ "${data.media}/audiobooks" ];
            collectionType = "books";
          };
          Books = {
            paths = [ "${data.media}/books" ];
            collectionType = "books";
          };
        };

        plugins = {
          "Open Subtitles" = {
            enable = true;
            config = {
              Username = config.sops.placeholder.opensubtitles_username;
              Password._secret = config.sops.secrets.opensubtitles_password.path;
            };
          };
          subbuzz = {
            enable = true;
            config = {
              OpenSubUserName = config.sops.placeholder.opensubtitles_username;
              OpenSubPassword._secret = config.sops.secrets.opensubtitles_password.path;
              OpenSubApiKey._secret = config.sops.secrets.opensubtitles_api_key.path;
              EnableOpenSubtitles = true;
              EnableYifySubtitles = true;
              Cache.SubLifeInMinutes = 43200;
            };
          };
          "Subtitle Extract" = {
            enable = true;
            config = {
              ExtractionDuringLibraryScan = true;
            };
          };
        };
      };

      seerr = {
        inherit (cfg.services.seerr) enable;
        package = lib.mkForce pkgs.jellyseerr;
        apiKey = secretRef "seerr_api_key";
        jellyfin.adminUsername = "admin";
        jellyfin.adminPassword = secretRef "jellyfin_admin_password";
        reverseProxy.expose = false;

        settings.users.defaultPermissions = 160; # REQUEST + AUTO_APPROVE
      };

      recyclarr = {
        inherit (cfg.services.recyclarr) enable;
      };

      torrentClients.qbittorrent = {
        enable = true;
        vpn.enable = true;
        webuiPort = 8080;
        password = secretRef "qbittorrent_password";

        serverConfig = {
          LegalNotice.Accepted = true;
          Preferences.WebUI = {
            Username = "admin";
            Password_PBKDF2 = "@ByteArray(dI5bnX+DU48zW531C2d97g==:B9Q6zq47r0mGzMLhbsLZqzN8z6lhi3GORGve8YWhd/kSrln30iXxxT2OsXJ0H6mzWiL7N6DAA078qi7nslp2Ew==)";
          };
        };

        categories = {
          "sonarr" = "${data.downloads}/torrent/tv";
          "radarr" = "${data.downloads}/torrent/movies";
          "sonarr-anime" = "${data.downloads}/torrent/anime";
          "prowlarr" = "${data.downloads}/torrent/prowlarr";
        };

        reverseProxy.expose = false;
      };
    };

    homelab.services =
      lib.genAttrs arrServices (name: {
        upstream.host = lib.mkDefault config.nixflix.${name}.connectionAddress;
      })
      // {
        qbittorrent = {
          upstream.host = lib.mkDefault config.nixflix.torrentClients.qbittorrent.connectionAddress;
          auth.bypassForApi = true;
          expose = {
            pathPrefix = null;
            redirectToPrefix = false;
          };
        };
      };

    systemd.services.flaresolverr = lib.mkIf cfg.services.prowlarr.enable {
      vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };
    };

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
        serviceConfig = lib.mkMerge [
          (lib.mkIf cfg.services.jellyfin.enable {
            # PrivateUsers makes chown in the container fall on host as nobody:nogroup,
            # which breaks SQLite writes for Jellyfin auth.
            PrivateUsers = lib.mkForce false;
            ExecStartPre =
              let
                jfDir = config.nixflix.jellyfin.dataDir;
                jfUser = config.nixflix.jellyfin.user;
                jfGroup = config.nixflix.jellyfin.group;
                fixJellyfinState = pkgs.writeShellScript "jellyfin-fix-state-ownership" ''
                  if [ -d ${lib.escapeShellArg jfDir} ]; then
                    chown -R ${lib.escapeShellArg "${jfUser}:${jfGroup}"} ${lib.escapeShellArg jfDir}
                  fi
                '';
              in
              lib.mkBefore [ "+${fixJellyfinState}" ];
          })
          (lib.mkIf (cfg.services.jellyfin.enable && jellyfinHwAccel.enable) {
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
          })
        ];
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
