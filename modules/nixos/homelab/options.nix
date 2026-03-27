{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;

  mkServiceOptions =
    {
      name,
      subdomain,
      port,
      exposeEnable ? true,
      authGroup ? null,
      pathPrefix ? null,
      redirectToPrefix ? false,
      dataGroups ? [ ],
    }:
    {
      enable = mkEnableOption "${name} service";

      user = mkOption {
        type = types.str;
        default = name;
        description = "System user running ${name}.";
      };

      group = mkOption {
        type = types.str;
        default = name;
        description = "Primary group for ${name}.";
      };

      dataGroups = mkOption {
        type = types.listOf types.str;
        default = dataGroups;
        description = "Shared data-role groups granted to ${name}.";
      };

      expose = {
        enable = mkOption {
          type = types.bool;
          default = exposeEnable;
          description = "Expose ${name} via Caddy.";
        };

        subdomain = mkOption {
          type = types.str;
          default = subdomain;
          description = "Subdomain for ${name}.";
        };

        pathPrefix = mkOption {
          type = types.nullOr types.str;
          default = pathPrefix;
          description = "Optional path prefix used by ${name}.";
        };

        redirectToPrefix = mkOption {
          type = types.bool;
          default = redirectToPrefix;
          description = "Redirect / to the path prefix for ${name}.";
        };

        reverseProxyExtraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "Extra config appended inside reverse_proxy for ${name}.";
        };
      };

      auth = {
        group = mkOption {
          type = types.nullOr types.str;
          default = authGroup;
          description = "Auth group applied at the proxy for ${name}.";
        };

        bypassForApi = mkOption {
          type = types.bool;
          default = false;
          description = "Bypass proxy auth for /api/* on ${name}.";
        };
      };

      upstream = {
        scheme = mkOption {
          type = types.enum [
            "http"
            "https"
          ];
          default = "http";
          description = "Upstream scheme for ${name}.";
        };

        host = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Upstream host for ${name}.";
        };

        port = mkOption {
          type = types.port;
          default = port;
          description = "Upstream port for ${name}.";
        };
      };

      backup = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Include ${name} data in homelab backups.";
        };

        paths = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Service-specific backup paths registered by ${name}.";
        };

        exclude = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Service-specific exclude patterns for ${name} backups.";
        };
      };
    };
in
{
  options.homelab = {
    enable = mkEnableOption "homelab base";

    domain = mkOption {
      type = types.str;
      default = "pieczarkowo.me";
      description = "Base domain for homelab services.";
    };

    proxy.enable = mkEnableOption "Caddy reverse proxy";

    ssh.authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Public SSH keys allowed to log in to the homelab admin user.";
    };

    state = {
      root = mkOption {
        type = types.path;
        default = "/var/lib/homelab";
        description = "Root directory for homelab service state.";
      };

      nixarr = mkOption {
        type = types.path;
        default = "/var/lib/homelab/nixarr";
        description = "State directory for nixarr-managed services.";
      };

      jellyfin = mkOption {
        type = types.path;
        default = "/var/lib/homelab/jellyfin";
        description = "State directory for Jellyfin.";
      };

      immichHot = mkOption {
        type = types.path;
        default = "/var/lib/homelab/immich-hot";
        description = "SSD-backed hot data directory for Immich.";
      };

      actual = mkOption {
        type = types.path;
        default = "/var/lib/homelab/actual";
        description = "State directory for Actual Budget.";
      };
    };

    data = {
      root = mkOption {
        type = types.path;
        default = "/data";
        description = "Root directory for all homelab data.";
      };

      media = mkOption {
        type = types.path;
        default = "/data/media";
        description = "Final media library directory.";
      };

      downloads = mkOption {
        type = types.path;
        default = "/data/downloads";
        description = "Downloads/import directory.";
      };

      photos = mkOption {
        type = types.path;
        default = "/data/photos";
        description = "Photo library directory.";
      };

      nas = mkOption {
        type = types.path;
        default = "/data/nas";
        description = "NAS/shared data directory.";
      };
    };

    backup = {
      enable = mkEnableOption "restic backups for homelab data";

      mountPoint = mkOption {
        type = types.str;
        default = "/mnt/backup-router";
        description = "Mountpoint for the router SMB backup share.";
      };

      repositoryPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Absolute path to the restic repository (defaults to mountPoint/restic/<host>).";
      };

      schedule = mkOption {
        type = types.str;
        default = "03:30";
        description = "Systemd OnCalendar value for nightly backups.";
      };

      checkSchedule = mkOption {
        type = types.str;
        default = "Sun 04:30";
        description = "Systemd OnCalendar value for restic repository checks.";
      };
    };

    profiles = {
      media.enable = mkEnableOption "media stack profile";
      photos.enable = mkEnableOption "photos stack profile";
      files.enable = mkEnableOption "files stack profile";
      admin.enable = mkEnableOption "admin stack profile";
    };

    auth.groups = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            type = mkOption {
              type = types.enum [ "basic" ];
              default = "basic";
              description = "Auth mechanism used by the group.";
            };

            secretRef = mkOption {
              type = types.str;
              description = "Base secret name for the auth group.";
            };
          };
        }
      );
      default = {
        media-admin = {
          type = "basic";
          secretRef = "media_admin_basic_auth";
        };
        infra-admin = {
          type = "basic";
          secretRef = "infra_admin_basic_auth";
        };
      };
      description = "Auth groups available to the proxy.";
    };

    services = {
      sonarr = mkServiceOptions {
        name = "sonarr";
        subdomain = "sonarr";
        port = 8989;
        authGroup = "media-admin";
        dataGroups = [ "media" ];
      };

      radarr = mkServiceOptions {
        name = "radarr";
        subdomain = "radarr";
        port = 7878;
        authGroup = "media-admin";
        dataGroups = [ "media" ];
      };

      prowlarr = mkServiceOptions {
        name = "prowlarr";
        subdomain = "indexers";
        port = 9696;
        authGroup = "media-admin";
      };

      bazarr = mkServiceOptions {
        name = "bazarr";
        subdomain = "bazarr";
        port = 6767;
        authGroup = "media-admin";
        dataGroups = [ "media" ];
        exposeEnable = false;
      };

      transmission = mkServiceOptions {
        name = "transmission";
        subdomain = "pobieralnia";
        port = 9091;
        authGroup = "media-admin";
        pathPrefix = "/transmission";
        redirectToPrefix = true;
        dataGroups = [ "media" ];
      };

      jellyfin = mkServiceOptions {
        name = "jellyfin";
        subdomain = "grzybflix";
        port = 8096;
        dataGroups = [ "media" ];
      };

      jellyseerr = mkServiceOptions {
        name = "jellyseerr";
        subdomain = "chciejnik";
        port = 5055;
      };

      audiobookshelf = mkServiceOptions {
        name = "audiobookshelf";
        subdomain = "czytelnia";
        port = 9292;
        pathPrefix = "/audiobookshelf";
        redirectToPrefix = true;
        dataGroups = [ "media" ];
      };

      readarr = mkServiceOptions {
        name = "readarr";
        subdomain = "readarr";
        port = 8787;
        authGroup = "media-admin";
        dataGroups = [ "media" ];
        exposeEnable = false;
      };

      "readarr-audiobook" = mkServiceOptions {
        name = "readarr-audiobook";
        subdomain = "readarr-audiobook";
        port = 8788;
        authGroup = "media-admin";
        dataGroups = [ "media" ];
        exposeEnable = false;
      };

      immich = mkServiceOptions {
        name = "immich";
        subdomain = "fotki";
        port = 2283;
        dataGroups = [ "photos" ];
      };

      copyparty = mkServiceOptions {
        name = "copyparty";
        subdomain = "pliki";
        port = 3923;
        dataGroups = [ "nas" ];
      };

      cockpit = mkServiceOptions {
        name = "cockpit";
        subdomain = "admin";
        port = 9090;
        authGroup = "infra-admin";
        exposeEnable = false;
      };

      actual = mkServiceOptions {
        name = "actual";
        subdomain = "kasa";
        port = 3100;
      };
    };

    media.vpn.wgConfSecretName = mkOption {
      type = types.str;
      default = "nixarr_wireguard";
      description = "SOPS secret name for the WireGuard config used by Transmission.";
    };
  };
}
