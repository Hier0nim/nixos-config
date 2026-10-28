{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  mediaPackages = pkgs.extend self.inputs.nixflix.overlays.default;

  secretFiles = {
    sonarr = [
      "api-key"
      "password"
    ];
    "sonarr-anime" = [
      "api-key"
      "password"
    ];
    radarr = [
      "api-key"
      "password"
    ];
    prowlarr = [
      "api-key"
      "password"
    ];
    jellyfin = [
      "api-key"
      "admin-password"
      "pieczarkowo-password"
      "opensubtitles-username"
      "opensubtitles-password"
      "opensubtitles-api-key"
      "subdl-api-key"
    ];
    seerr = [ "api-key" ];
    qbittorrent = [ "password" ];
    "media-vpn" = [ "wireguard.conf" ];
  };

  mkSecretGenerator = name: files: {
    files = lib.genAttrs files (_: {
      owner = "root";
      group = "root";
      mode = "0400";
    });
    prompts = lib.genAttrs files (file: {
      description = "${name} ${file}";
      type = if file == "wireguard.conf" then "multiline-hidden" else "hidden";
    });
    runtimeInputs = [ pkgs.coreutils ];
    script = lib.concatMapStringsSep "\n" (file: ''
      install -m 0400 "$prompts/${file}" "$out/${file}"
    '') files;
  };

  secretPath = service: name: config.clan.core.vars.generators.${service}.files.${name}.path;
  secretRef = service: name: { _secret = secretPath service name; };

  arrServices = [
    "sonarr"
    "sonarr-anime"
    "radarr"
    "prowlarr"
  ];
  mediaWriterUsers = [
    "sonarr"
    "sonarr-anime"
    "radarr"
    "jellyfin"
    "maintainerr"
    "qbittorrent"
  ];

  mkArr = name: {
    enable = true;
    user = name;
    group = name;
    package = mediaPackages.${if name == "sonarr-anime" then "sonarr" else name};
    vpn.enable = true;
    config = {
      apiKey = secretRef name "api-key";
      hostConfig = {
        password = secretRef name "password";
        backupInterval = 1;
        backupRetention = 28;
      };
    }
    // lib.optionalAttrs (name == "prowlarr") {
      indexers = [
        { name = "YTS"; }
        { name = "Nyaa.si"; }
        { name = "LimeTorrents"; }
      ];
      applications = [
        {
          name = "Sonarr";
          implementationName = "Sonarr";
          apiKey = secretRef "sonarr" "api-key";
        }
        {
          name = "Sonarr Anime";
          implementationName = "Sonarr";
          apiKey = secretRef "sonarr-anime" "api-key";
        }
        {
          name = "Radarr";
          implementationName = "Radarr";
          apiKey = secretRef "radarr" "api-key";
        }
      ];
    };
    reverseProxy.expose = false;
  };
in
{
  imports = [ self.inputs.nixflix.nixosModules.default ];

  nixpkgs.overlays = [ self.inputs.nixflix.overlays.default ];
  users.users =
    lib.genAttrs mediaWriterUsers (_: {
      extraGroups = [ "media" ];
    })
    // {
      jellyfin.extraGroups = [
        "media"
        "video"
        "render"
      ];
    };

  clan.core.vars.generators = lib.mapAttrs mkSecretGenerator secretFiles;

  nixflix = {
    enable = true;
    mediaDir = "/data/media";
    downloadsDir = "/data/downloads";
    stateDir = "/var/lib/homelab/nixflix";
    mediaUsers = mediaWriterUsers;
    caddy.enable = false;
    nginx.enable = false;
    vpn = {
      enable = true;
      wgConfFile = secretPath "media-vpn" "wireguard.conf";
    };
    flaresolverr.enable = true;
  }
  // lib.genAttrs arrServices mkArr
  // {
    jellyfin = {
      enable = true;
      package = mediaPackages.jellyfin;
      system.serverName = "Grzybflix";
      reverseProxy.expose = false;
      apiKey = secretRef "jellyfin" "api-key";
      branding.customCss = ''
        @import url("https://cdn.jsdelivr.net/gh/lscambo13/ElegantFin@main/Theme/ElegantFin-jellyfin-theme-build-latest-minified.css");
        @import url("https://cdn.jsdelivr.net/gh/mihaif7/elegantfin-jf12@main/Theme/ElegantFin-jf12-modern-latest.css");
      '';
      users.admin = {
        policy.isAdministrator = true;
        password = secretRef "jellyfin" "admin-password";
        mutable = false;
        configuration = {
          audioLanguagePreference = "pol";
          subtitleLanguagePreference = "eng";
          subtitleMode = "Smart";
        };
      };
      users.pieczarkowo = {
        password = secretRef "jellyfin" "pieczarkowo-password";
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
        hardwareAccelerationType = "nvenc";
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
          paths = [ "/data/media/movies" ];
          collectionType = "movies";
          enableRealtimeMonitor = true;
          saveLocalMetadata = false;
          subtitleFetcherOrder = [
            "subbuzz"
            "Open Subtitles"
          ];
          subtitleDownloadLanguages = [
            "eng"
            "pol"
          ];
          saveSubtitlesWithMedia = true;
          requirePerfectSubtitleMatch = false;
          skipSubtitlesIfEmbeddedSubtitlesPresent = true;
        };
        Shows = {
          paths = [ "/data/media/tv" ];
          collectionType = "tvshows";
          enableRealtimeMonitor = true;
          subtitleFetcherOrder = [
            "subbuzz"
            "Open Subtitles"
          ];
          subtitleDownloadLanguages = [
            "eng"
            "pol"
          ];
          saveSubtitlesWithMedia = true;
          requirePerfectSubtitleMatch = false;
          skipSubtitlesIfEmbeddedSubtitlesPresent = true;
        };
        Anime = {
          paths = [ "/data/media/anime" ];
          collectionType = "tvshows";
          enableRealtimeMonitor = true;
          subtitleFetcherOrder = [
            "subbuzz"
            "Open Subtitles"
          ];
          subtitleDownloadLanguages = [
            "eng"
            "pol"
          ];
          saveSubtitlesWithMedia = true;
          requirePerfectSubtitleMatch = false;
          skipSubtitlesIfEmbeddedSubtitlesPresent = true;
        };
      };
      plugins = {
        subbuzz = {
          enable = true;
          config = {
            OpenSubUserName = "";
            OpenSubPassword = secretRef "jellyfin" "opensubtitles-password";
            OpenSubApiKey = secretRef "jellyfin" "opensubtitles-api-key";
            EnableOpenSubtitles = false;
            EnableSubdlCom = true;
            SubdlApiKey = secretRef "jellyfin" "subdl-api-key";
            EnableYifySubtitles = true;
            Cache = {
              SubLifeInMinutes = "Always";
              Search = true;
              SearchLifeInMinutes = "4 weeks";
            };
          };
        };
        "Open Subtitles" = {
          enable = true;
          config = {
            Username = "";
            Password = secretRef "jellyfin" "opensubtitles-password";
          };
        };
        "Subtitle Extract" = {
          enable = true;
          config.ExtractionDuringLibraryScan = true;
        };
      };
    };

    seerr = {
      enable = true;
      package = mediaPackages.seerr;
      apiKey = secretRef "seerr" "api-key";
      jellyfin.adminUsername = "admin";
      jellyfin.adminPassword = secretRef "jellyfin" "admin-password";
      reverseProxy.expose = false;
      settings.users.defaultPermissions = 160;
    };

    recyclarr.enable = true;

    maintainerr = {
      enable = true;
      package = mediaPackages.maintainerr;
      reverseProxy.expose = false;
      settings = {
        forceJellyfinToIgnoreEmptyMediaFolders = false;
        jobs.rules_handler_job_cron = "0 * * * *";
        jobs.collection_handler_job_cron = "30 5 * * *";
      };
      rules = import ./maintainerr-rules.nix { inherit lib; };
    };

    torrentClients.qbittorrent = {
      enable = true;
      package = mediaPackages.qbittorrent-nox;
      user = "qbittorrent";
      group = "qbittorrent";
      vpn.enable = true;
      webuiPort = 8080;
      password = secretRef "qbittorrent" "password";
      serverConfig = {
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
        sonarr = "/data/downloads/torrent/tv";
        radarr = "/data/downloads/torrent/movies";
        "sonarr-anime" = "/data/downloads/torrent/anime";
        prowlarr = "/data/downloads/torrent/prowlarr";
        audiobooks = "/data/downloads/torrent/audiobooks";
      };
      reverseProxy.expose = false;
    };

    downloadarr.qbittorrent.categories.prowlarr = "audiobooks";
  };

  services.flaresolverr.package = mediaPackages.flaresolverr;
  services.recyclarr.package = mediaPackages.recyclarr;

  systemd.services = {
    flaresolverr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
    jellyfin-plugin-usernames = {
      description = "Apply secret usernames to Jellyfin subtitle plugins";
      after = [
        "jellyfin-api-key.service"
        "jellyfin-plugins.service"
      ];
      requires = [
        "jellyfin-api-key.service"
        "jellyfin-plugins.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.curl
        pkgs.jq
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = [
          "username:${secretPath "jellyfin" "opensubtitles-username"}"
        ];
      };
      script = ''
        set -euo pipefail
        umask 0077
        BASE_URL="http://${config.nixflix.jellyfin.connectionAddress}:${toString config.nixflix.jellyfin.network.internalHttpPort}"
        CURRENT_CONFIG="$(mktemp)"
        DESIRED_CONFIG="$(mktemp)"
        trap 'rm -f "$CURRENT_CONFIG" "$DESIRED_CONFIG"' EXIT

        apply_username() {
          plugin_name="$1"
          config_key="$2"
          plugin_id=$(curl --fail --silent --show-error \
            --variable "authToken@/run/jellyfin/auth-token" \
            --expand-header 'Authorization: {{authToken:trim}}' "$BASE_URL/Plugins" \
            | jq -r --arg name "$plugin_name" '.[] | select(.Name == $name) | .Id // empty')
          if [ -z "$plugin_id" ]; then
            echo "Jellyfin plugin not found: $plugin_name" >&2
            exit 1
          fi
          curl --fail --silent --show-error \
            --variable "authToken@/run/jellyfin/auth-token" \
            --expand-header 'Authorization: {{authToken:trim}}' \
            "$BASE_URL/Plugins/$plugin_id/Configuration" > "$CURRENT_CONFIG"
          jq --rawfile username "$CREDENTIALS_DIRECTORY/username" --arg key "$config_key" \
            '.[$key] = ($username | rtrimstr("\\n"))' \
            "$CURRENT_CONFIG" > "$DESIRED_CONFIG"
          curl --fail --silent --show-error \
            --variable "authToken@/run/jellyfin/auth-token" \
            --expand-header 'Authorization: {{authToken:trim}}' \
            -H 'Content-Type: application/json' -X POST --data-binary "@$DESIRED_CONFIG" \
            "$BASE_URL/Plugins/$plugin_id/Configuration" >/dev/null
        }

        apply_username "subbuzz" "OpenSubUserName"
        apply_username "Open Subtitles" "Username"
      '';
    };
  };

}
