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
  homelabMeta = import ../meta-data.nix;
  inherit (homelabMeta) nixflixStateServices;
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
    "subdl_api_key"
    "sonarr_anime_api_key"
    "sonarr_anime_password"
    "jellyfin_pieczarkowo_password"
  ]
  ++ lib.optional cfg.services.prowlarr.indexers.abtorrents.enable "abtorrents_cookie";

  arrServices = [
    "sonarr"
    "sonarr-anime"
    "radarr"
    "prowlarr"
  ];

  mkNixflixApp =
    name:
    let
      svc = cfg.services.${name};
      needsDownloads = builtins.elem name [
        "qbittorrent"
        "radarr"
        "sonarr"
        "sonarr-anime"
      ];
      baseStorageAccess = lib.filter (
        role:
        builtins.elem role [
          "media"
          "photos"
          "nas"
        ]
      ) svc.dataGroups;
      storageAccess = lib.unique (baseStorageAccess ++ lib.optional needsDownloads "downloads");
    in
    lib.mkIf svc.enable {
      ${name} = {
        enable = true;
        inherit (svc) user group;
        manageUser = true;
        serviceNames = [ name ];
        inherit storageAccess;
        sharedWriter = svc.umaskSharedWriter && storageAccess != [ ];
        state.paths = [ "${cfg.state.nixflix}/${name}" ];
      };
    };
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
            { name = "Nyaa.si"; }
            { name = "LimeTorrents"; }
            { name = "AnimeTosho"; }
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

        system.pluginRepositories."Intro Skipper" = {
          url = "https://raw.githubusercontent.com/intro-skipper/manifest/main/10.11/manifest.json";
          hash = "sha256-04zM8nfxcnpK5dITdiDjPmySv6YlXEsc7Nef5fr7cuU=";
        };
        system.pluginRepositories."Jellyfin Stable".hash =
          lib.mkForce "sha256-fd1auhliBL4maySfnwRpsjiK7yQpiQTJb6ffozy/efo=";

        users.admin = {
          policy.isAdministrator = true;
          password = secretRef "jellyfin_admin_password";
          mutable = false;
          configuration = {
            audioLanguagePreference = "pol";
            subtitleLanguagePreference = "eng";
            subtitleMode = "Smart";
          };
        };

        users.pieczarkowo = {
          password = secretRef "jellyfin_pieczarkowo_password";
          mutable = false;
          policy.enableSubtitleManagement = true;
          configuration = {
            displayMissingEpisodes = false;
            enableNextEpisodeAutoPlay = true;
            audioLanguagePreference = "pol";
            subtitleLanguagePreference = "eng";
            subtitleMode = "Smart";
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
          Shows = {
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
        };

        plugins = {
          subbuzz = {
            enable = true;
            config = {
              OpenSubUserName = config.sops.placeholder.opensubtitles_username;
              OpenSubPassword._secret = config.sops.secrets.opensubtitles_password.path;
              OpenSubApiKey._secret = config.sops.secrets.opensubtitles_api_key.path;
              EnableOpenSubtitles = true;
              EnableSubdlCom = true;
              SubdlApiKey._secret = config.sops.secrets.subdl_api_key.path;
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
          "Intro Skipper" = {
            enable = true;
            package = {
              version = "1.10.11.17";
              hash = "sha256-cfEnLqKeEGpQSth3NPjDnxCkgv2pePfgCXfVIOrYSiQ=";
              repository = "Intro Skipper";
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
          # Separate download/upload queues so seeding never blocks downloading.
          # MaxActiveTorrents = MaxActiveDownloads + MaxActiveUploads ensures
          # the two pools don't share slots.
          BitTorrent.Session = {
            QueueingEnabled = true;
            MaxActiveDownloads = 10;
            MaxActiveUploads = 10;
            MaxActiveTorrents = 20;
            DoNotCountSlowTorrents = true;
          };
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
          "audiobooks" = "${data.downloads}/torrent/audiobooks";
        };

        reverseProxy.expose = false;
      };

      # Prowlarr is used as a manual discovery/search UI for audiobooks.
      # Manual grabs should land in the curated audiobook staging lane.
      downloadarr.qbittorrent.categories.prowlarr = "audiobooks";
    };

    homelab.services =
      lib.genAttrs arrServices (name: {
        upstream.host = lib.mkDefault config.nixflix.${name}.connectionAddress;
      })
      // {
        qbittorrent = {
          upstream.host = lib.mkDefault config.nixflix.torrentClients.qbittorrent.connectionAddress;
          auth.bypassForApi = true;
          auth.stripAuthorizationHeader = true;
          expose = {
            pathPrefix = null;
            redirectToPrefix = false;
          };
        };
      };

    homelab.apps = lib.mkMerge [
      (lib.mkMerge (map mkNixflixApp nixflixStateServices))
      (lib.mkIf cfg.services.jellyfin.enable {
        jellyfin = {
          enable = true;
          user = config.nixflix.jellyfin.user;
          group = config.nixflix.jellyfin.group;
          serviceNames = [
            "jellyfin"
            "jellyfin-libraries"
          ];
          storageAccess = [ "media" ];
          state = {
            mode = "0755";
            paths = [
              config.nixflix.jellyfin.dataDir
              config.nixflix.jellyfin.configDir
              config.nixflix.jellyfin.cacheDir
              config.nixflix.jellyfin.logDir
              config.nixflix.jellyfin.system.metadataPath
              "${config.nixflix.jellyfin.dataDir}/plugins"
            ];
          };
        };
      })
    ];

    systemd = {
      services = {
        nixflix-setup-dirs = {
          script = lib.mkForce ''
            ${pkgs.systemd}/bin/systemd-tmpfiles --create \
              --prefix=${lib.escapeShellArg cfg.state.nixflix} \
              --prefix=${lib.escapeShellArg data.media} \
              --prefix=${lib.escapeShellArg data.downloads}
          '';
        };

        prowlarr-indexer-abtorrents = lib.mkIf cfg.services.prowlarr.indexers.abtorrents.enable {
          description = "Configure ABtorrents Prowlarr indexer via API";
          after = [ "prowlarr-indexers.service" ];
          requires = [ "prowlarr-indexers.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            pkgs.curl
            pkgs.jq
          ];
          script = ''
            set -euo pipefail

            BASE_URL="http://${config.nixflix.prowlarr.connectionAddress}:${toString config.nixflix.prowlarr.config.hostConfig.port}${config.nixflix.prowlarr.config.hostConfig.urlBase}/api/${config.nixflix.prowlarr.config.apiVersion}"
            API_KEY="$(cat ${config.sops.secrets.prowlarr_api_key.path})"
            COOKIE="$(cat ${config.sops.secrets.abtorrents_cookie.path})"

            echo "Configuring ABtorrents indexer..."
            SCHEMAS=$(curl -sS -H "X-Api-Key: $API_KEY" "$BASE_URL/indexer/schema")
            INDEXERS=$(curl -sS -H "X-Api-Key: $API_KEY" "$BASE_URL/indexer")

            PAYLOAD=$(jq --arg cookie "$COOKIE" '
              .[] | select(.name == "ABtorrents")
              | .fields[] |= (
                  if .name == "cookie" then .value = $cookie
                  elif .name == "freeleech" then .value = false
                  elif .name == "torrentBaseSettings.appMinimumSeeders" then .value = 1
                  elif .name == "torrentBaseSettings.seedRatio" then .value = 99999
                  elif .name == "torrentBaseSettings.seedTime" then .value = 525600
                  elif .name == "torrentBaseSettings.packSeedTime" then .value = 525600
                  elif .name == "torrentBaseSettings.preferMagnetUrl" then .value = false
                  else .
                  end
                )
              | . + {appProfileId: 1, tags: []}
            ' <<<"$SCHEMAS")

            EXISTING_ID=$(jq -r '.[] | select(.name == "ABtorrents") | .id' <<<"$INDEXERS")
            RESPONSE=$(mktemp)

            if [ -n "$EXISTING_ID" ]; then
              echo "ABtorrents already exists, updating..."
              METHOD=PUT
              URL="$BASE_URL/indexer/$EXISTING_ID"
            else
              echo "ABtorrents does not exist, creating..."
              METHOD=POST
              URL="$BASE_URL/indexer"
            fi

            CODE=$(curl -sS -w '%{http_code}' -o "$RESPONSE" \
              -H "X-Api-Key: $API_KEY" \
              -H "Content-Type: application/json" \
              -X "$METHOD" \
              --data "$PAYLOAD" \
              "$URL")

            if [ "$CODE" -lt 200 ] || [ "$CODE" -ge 300 ]; then
              echo "ABtorrents indexer API request failed with HTTP $CODE" >&2
              jq 'if type == "array" then [.[] | {propertyName, errorMessage, severity, errorCode}] else . end' "$RESPONSE" >&2 || cat "$RESPONSE" >&2
              exit 1
            fi

            echo "ABtorrents indexer configured"
          '';
        };

        flaresolverr = lib.mkIf cfg.services.prowlarr.enable {
          vpnConfinement = {
            enable = true;
            vpnNamespace = "wg";
          };
        };

        seerr-jellyfin = lib.mkIf (cfg.services.seerr.enable && cfg.services.jellyfin.enable) {
          after = [
            "seerr.service"
            "jellyfin.service"
          ];
          requires = [
            "seerr.service"
            "jellyfin.service"
          ];
        };

        jellyfin = {
          serviceConfig = lib.mkMerge [
            (lib.mkIf cfg.services.jellyfin.enable {
              # PrivateUsers makes chown in the container fall on host as nobody:nogroup,
              # which breaks SQLite writes for Jellyfin auth.
              PrivateUsers = lib.mkForce false;
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
    };
  };
}
