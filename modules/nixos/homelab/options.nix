{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;

  mkHwAccelOptions =
    {
      accelTypes ? [
        "nvenc"
        "vaapi"
      ],
      defaultType ? "nvenc",
    }:
    {
      enable = mkEnableOption "hardware-accelerated transcoding";

      type = mkOption {
        type = types.enum accelTypes;
        default = defaultType;
        description = "Hardware acceleration backend.";
      };

      device = mkOption {
        type = types.path;
        default = "/dev/nvidia0";
        description = "Primary GPU device node.";
      };
    };

  mkServiceOptions =
    {
      name,
      subdomain,
      port,
      exposeEnable ? true,
      authGroup ? null,
      pathPrefix ? null,
      redirectToPrefix ? false,
      openFirewall ? false,
      dataGroups ? [ ],
      stripAuthorizationHeader ? false,
      runsUnderNixflix ? false,
      umaskSharedWriter ? false,
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

      runsUnderNixflix = mkOption {
        type = types.bool;
        default = runsUnderNixflix;
        readOnly = true;
        internal = true;
        description = "Whether ${name} state is managed by nixflix.";
      };

      umaskSharedWriter = mkOption {
        type = types.bool;
        default = umaskSharedWriter;
        readOnly = true;
        internal = true;
        description = "Whether ${name} needs UMask=0002 for shared-data writes.";
      };

      expose = {
        enable = mkOption {
          type = types.bool;
          default = exposeEnable;
          description = "Expose ${name} via Caddy.";
        };

        tls = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                certFile = mkOption {
                  type = types.str;
                  description = "Path to a PEM fullchain certificate file for ${name}.";
                };

                keyFile = mkOption {
                  type = types.str;
                  description = "Path to a PEM private key file for ${name}.";
                };
              };
            }
          );
          default = null;
          description = "Optional manual TLS configuration for ${name} (disables Caddy's ACME for this host).";
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

        stripAuthorizationHeader = mkOption {
          type = types.bool;
          default = stripAuthorizationHeader;
          description = ''
            Remove Authorization-style request headers before proxying to ${name}.
            Enable this when Caddy handles auth and the upstream service treats
            forwarded Basic, Bearer, or API-key credentials as its own invalid API token.
          '';
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

      openFirewall = mkOption {
        type = types.bool;
        default = openFirewall;
        description = "Open firewall port for ${name}.";
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

      nixflix = mkOption {
        type = types.path;
        default = "/var/lib/homelab/nixflix";
        description = "State directory for nixflix-managed services.";
      };

      tdarr = mkOption {
        type = types.path;
        default = "/var/lib/homelab/tdarr";
        description = "State directory for Tdarr.";
      };

      immichHot = mkOption {
        type = types.path;
        default = "/var/lib/homelab/immich-hot";
        description = "SSD-backed hot data directory for Immich.";
      };

      actual = mkOption {
        type = types.path;
        default = "/var/lib/actual";
        description = "State directory for Actual Budget.";
      };

      enableActual = mkOption {
        type = types.path;
        default = "/var/lib/homelab/enable-actual";
        description = "State directory for Enable Actual.";
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

      models = mkOption {
        type = types.path;
        default = "/data/models";
        description = "Root directory for local model files and other large AI artifacts.";
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
        runsUnderNixflix = true;
        umaskSharedWriter = true;
      };

      radarr = mkServiceOptions {
        name = "radarr";
        subdomain = "radarr";
        port = 7878;
        authGroup = "media-admin";
        dataGroups = [ "media" ];
        runsUnderNixflix = true;
        umaskSharedWriter = true;
      };

      prowlarr = mkServiceOptions {
        name = "prowlarr";
        subdomain = "indexers";
        port = 9696;
        authGroup = "media-admin";
        runsUnderNixflix = true;
        umaskSharedWriter = true;
      };

      sonarr-anime = mkServiceOptions {
        name = "sonarr-anime";
        subdomain = "sonarr-anime";
        port = 8990;
        authGroup = "media-admin";
        dataGroups = [ "media" ];
        runsUnderNixflix = true;
        umaskSharedWriter = true;
      };

      jellyfin =
        mkServiceOptions {
          name = "jellyfin";
          subdomain = "grzybflix";
          port = 8096;
          dataGroups = [ "media" ];
        }
        // {
          hardwareAcceleration = mkHwAccelOptions {
            accelTypes = [
              "amf"
              "nvenc"
              "qsv"
              "rkmpp"
              "v4l2m2m"
              "vaapi"
            ];
            defaultType = "nvenc";
          };
        };

      seerr = mkServiceOptions {
        name = "seerr";
        subdomain = "chciejnik";
        port = 5055;
        runsUnderNixflix = true;
      };

      tdarr =
        mkServiceOptions {
          name = "tdarr";
          subdomain = "tdarr";
          port = 8265;
          authGroup = "media-admin";
          dataGroups = [ "media" ];
        }
        // {
          image = mkOption {
            type = types.str;
            default = "ghcr.io/haveagitgat/tdarr:2.58.02";
            description = "OCI image used for the Tdarr server container.";
          };

          cacheDir = mkOption {
            type = types.path;
            default = "/var/lib/homelab/tdarr/cache";
            description = "Temporary working directory used by Tdarr while transcoding.";
          };

          hardwareAcceleration = mkHwAccelOptions { };
        };

      recyclarr = mkServiceOptions {
        name = "recyclarr";
        subdomain = "recyclarr";
        port = 1;
        exposeEnable = false;
        dataGroups = [ ];
        runsUnderNixflix = true;
      };

      qbittorrent = mkServiceOptions {
        name = "qbittorrent";
        subdomain = "pobieralnia";
        port = 8080;
        authGroup = "media-admin";
        pathPrefix = "/qbittorrent";
        redirectToPrefix = true;
        dataGroups = [ "media" ];
        runsUnderNixflix = true;
        umaskSharedWriter = true;
      };

      immich =
        mkServiceOptions {
          name = "immich";
          subdomain = "fotki";
          port = 2283;
          dataGroups = [ "photos" ];
        }
        // {
          hardwareAcceleration = mkHwAccelOptions { };
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

      "enable-actual" =
        mkServiceOptions {
          name = "enable-actual";
          subdomain = "actual-sync";
          port = 3000;
          authGroup = "infra-admin";
        }
        // {
          image = mkOption {
            type = types.str;
            default = "2manyvcos/enable-actual";
            description = "OCI image used for the Enable Actual container.";
          };
        };
    };

    media.vpn.wgConfSecretName = mkOption {
      type = types.str;
      default = "nixarr_wireguard";
      description = "SOPS secret name for the WireGuard config used by qBittorrent.";
    };
  };

}
