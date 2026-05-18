{ lib, pkgs, ... }:
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
      openFirewall ? false,
      dataGroups ? [ ],
      stripAuthorizationHeader ? false,
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
            Remove the Authorization request header before proxying to ${name}.
            Enable this when Caddy handles auth and the upstream service treats
            forwarded Basic or Bearer credentials as its own invalid API token.
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
      ai.enable = mkEnableOption "local AI stack profile";
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
        exposeEnable = true;
      };

      jellyfin =
        (mkServiceOptions {
          name = "jellyfin";
          subdomain = "grzybflix";
          port = 8096;
          dataGroups = [ "media" ];
        })
        // {
          hardwareAcceleration = {
            enable = mkEnableOption "Jellyfin hardware-accelerated transcoding";

            type = mkOption {
              type = types.enum [
                "amf"
                "nvenc"
                "qsv"
                "rkmpp"
                "v4l2m2m"
                "vaapi"
              ];
              default = "nvenc";
              description = "Hardware acceleration backend for Jellyfin transcoding.";
            };

            device = mkOption {
              type = types.path;
              default = "/dev/nvidia0";
              description = "Device node used by Jellyfin for hardware acceleration.";
            };

          };
        };

      seerr = mkServiceOptions {
        name = "seerr";
        subdomain = "chciejnik";
        port = 5055;
      };

      tdarr =
        (mkServiceOptions {
          name = "tdarr";
          subdomain = "tdarr";
          port = 8265;
          authGroup = "media-admin";
          dataGroups = [ "media" ];
        })
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

          hardwareAcceleration = {
            enable = mkEnableOption "Tdarr hardware-accelerated transcoding";

            type = mkOption {
              type = types.enum [
                "nvenc"
                "vaapi"
              ];
              default = "nvenc";
              description = "Hardware acceleration backend exposed to Tdarr.";
            };

            device = mkOption {
              type = types.path;
              default = "/dev/nvidia0";
              description = "Primary hardware acceleration device path exposed to Tdarr.";
            };
          };
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
        exposeEnable = true;
      };

      "readarr-audiobook" = mkServiceOptions {
        name = "readarr-audiobook";
        subdomain = "readarr-audiobook";
        port = 9494;
        authGroup = "media-admin";
        dataGroups = [ "media" ];
        exposeEnable = true;
      };

      # Internal nixarr-managed helper with private state, not a proxied web app.
      recyclarr = mkServiceOptions {
        name = "recyclarr";
        subdomain = "recyclarr";
        port = 1;
        exposeEnable = false;
        dataGroups = [ ];
      };

      # qBittorrent
      qbittorrent = mkServiceOptions {
        name = "qbittorrent";
        subdomain = "pobieralnia";
        port = 8080;
        authGroup = "media-admin";
        pathPrefix = "/qbittorrent";
        redirectToPrefix = true;
        dataGroups = [ "media" ];
      };
      immich =
        (mkServiceOptions {
          name = "immich";
          subdomain = "fotki";
          port = 2283;
          dataGroups = [ "photos" ];
        })
        // {
          hardwareAcceleration = {
            enable = mkEnableOption "Immich hardware-accelerated transcoding";

            type = mkOption {
              type = types.enum [
                "nvenc"
                "vaapi"
              ];
              default = "nvenc";
              description = "Hardware acceleration backend used by Immich transcoding.";
            };

            device = mkOption {
              type = types.path;
              default = "/dev/nvidia0";
              description = "Primary device node exposed to Immich for hardware acceleration.";
            };
          };
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
        (mkServiceOptions {
          name = "enable-actual";
          subdomain = "actual-sync";
          port = 3000;
          authGroup = "infra-admin";
        })
        // {
          image = mkOption {
            type = types.str;
            default = "2manyvcos/enable-actual";
            description = "OCI image used for the Enable Actual container.";
          };
        };

      # Example host config:
      #
      # {
      #   homelab.profiles.ai.enable = true;
      #
      #   homelab.services."llama-cpp-agent" = {
      #     apiKeySecretName = "llama_cpp_agent_api_key";
      #     defaultModel = "qwen";
      #
      #     models.qwen = {
      #       name = "Qwen 3.6 35B A3B";
      #       file = "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf";
      #       url = "https://huggingface.co/bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf?download=true";
      #       sha256 = "6f5c72e2cde7fb0a1584cc009cdb4513f26733740369d3e2df0e7d7247112d05";
      #
      #       contextSize = 32768;
      #       gpuLayers = 99;
      #       cpuMoeLayers = 36;
      #       cacheTypeK = "turbo4";
      #       cacheTypeV = "turbo3";
      #       jinja = true;
      #     };
      #
      #     expose = {
      #       enable = true;
      #       subdomain = "ai";
      #       api = {
      #         enable = true;
      #         subdomain = "ai-api";
      #       };
      #     };
      #   };
      # }
      "llama-cpp-agent" =
        let
          base = mkServiceOptions {
            name = "llama-cpp-agent";
            subdomain = "ai";
            port = 8080;
            authGroup = "infra-admin";
            exposeEnable = false;
            stripAuthorizationHeader = true;
          };
        in
        base
        // {
          expose = base.expose // {
            api = {
              enable = mkOption {
                type = types.bool;
                default = false;
                description = "Expose a separate API hostname for the llama.cpp server.";
              };

              subdomain = mkOption {
                type = types.str;
                default = "ai-api";
                description = "Subdomain used for the llama.cpp API hostname.";
              };
            };
          };

          package = mkOption {
            type = types.package;
            default = pkgs.llama-cpp-turboquant;
            description = "llama.cpp package used for native llama-server model processes.";
          };

          autoStart = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to start the llama.cpp stack automatically during boot.";
          };

          dynamicStart = {
            idleStopMinutes = mkOption {
              type = types.int;
              default = 15;
              description = "Minutes of inactivity before llama-swap unloads the model. Set to 0 to keep it loaded.";
            };
          };

          apiKeySecretName = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Name of SOPS secret used for the llama.cpp API key.";
          };

          bindAddress = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Host address used for publishing the llama.cpp server port.";
          };

          modelDir = mkOption {
            type = types.path;
            default = "/data/models/llm";
            description = ''
              Host directory containing GGUF model files. Prefer an SSD/NVMe-backed path for
              dynamic model loading because llama.cpp must read the GGUF during cold starts.
            '';
          };

          defaultModel = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Default model id used for browser chat root redirects and examples.";
          };

          models = mkOption {
            type = types.attrsOf (
              types.submodule (
                { name, ... }:
                {
                  options = {
                    enable = mkOption {
                      type = types.bool;
                      default = true;
                      description = "Expose ${name} through llama-swap.";
                    };

                    download.enable = mkOption {
                      type = types.bool;
                      default = true;
                      description = "Download ${name} into modelDir before starting llama-swap.";
                    };

                    name = mkOption {
                      type = types.str;
                      default = name;
                      description = "Display name for ${name}.";
                    };

                    file = mkOption {
                      type = types.str;
                      default = "";
                      description = "GGUF model filename for ${name} inside modelDir.";
                    };

                    url = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Optional URL used by systemd to download ${name}.";
                    };

                    sha256 = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Optional SHA256 checksum for the downloaded ${name} GGUF file.";
                    };

                    ttl = mkOption {
                      type = types.nullOr types.int;
                      default = null;
                      description = "Seconds before llama-swap unloads ${name}. Defaults to dynamicStart.idleStopMinutes.";
                    };
                  }
                  //
                    (import ../shared/llama-cpp-model.nix {
                      inherit lib types;
                    })
                      {
                        inherit name;
                        descriptionPrefix = "llama-swap";
                      };
                }
              )
            );
            default = { };
            description = "llama-swap models keyed by API model id.";
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
