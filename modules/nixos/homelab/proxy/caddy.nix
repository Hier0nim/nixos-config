{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (config.networking) hostName;
  inherit (lib) mkIf optionalAttrs optionalString;

  caddySecretsFile = config.custom.repoPath + "/secrets/${hostName}/caddy.yaml";

  jellyfinFqdn = "${cfg.services.jellyfin.subdomain}.${cfg.domain}";
  immichFqdn = "${cfg.services.immich.subdomain}.${cfg.domain}";
  copypartyFqdn = "${cfg.services.copyparty.subdomain}.${cfg.domain}";
  jellyseerrFqdn = "${cfg.services.jellyseerr.subdomain}.${cfg.domain}";
  audiobookshelfFqdn = "${cfg.services.audiobookshelf.subdomain}.${cfg.domain}";
  transmissionFqdn = "${cfg.services.transmission.subdomain}.${cfg.domain}";
in
{
  config = mkIf (cfg.enable && cfg.proxy.enable) {
    sops.secrets =
      (optionalAttrs cfg.services.jellyseerr.protect {
        jellyseerr_user = {
          sopsFile = caddySecretsFile;
          key = "jellyseerr_user";
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };
        jellyseerr_hash = {
          sopsFile = caddySecretsFile;
          key = "jellyseerr_hash";
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };
      })
      // (optionalAttrs cfg.services.audiobookshelf.protect {
        audiobookshelf_user = {
          sopsFile = caddySecretsFile;
          key = "audiobookshelf_user";
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };
        audiobookshelf_hash = {
          sopsFile = caddySecretsFile;
          key = "audiobookshelf_hash";
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };
      })
      // (optionalAttrs cfg.services.transmission.protect {
        transmission_user = {
          sopsFile = caddySecretsFile;
          key = "transmission_user";
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };
        transmission_hash = {
          sopsFile = caddySecretsFile;
          key = "transmission_hash";
          owner = "caddy";
          group = "caddy";
          mode = "0400";
        };
      });

    sops.templates =
      (optionalAttrs cfg.services.jellyseerr.protect {
        "caddy-basic-auth-jellyseerr".content = ''
          basic_auth {
            ${config.sops.placeholder.jellyseerr_user} ${config.sops.placeholder.jellyseerr_hash}
          }
        '';
      })
      // (optionalAttrs cfg.services.audiobookshelf.protect {
        "caddy-basic-auth-audiobookshelf".content = ''
          basic_auth {
            ${config.sops.placeholder.audiobookshelf_user} ${config.sops.placeholder.audiobookshelf_hash}
          }
        '';
      })
      // (optionalAttrs cfg.services.transmission.protect {
        "caddy-basic-auth-transmission".content = ''
          basic_auth {
            ${config.sops.placeholder.transmission_user} ${config.sops.placeholder.transmission_hash}
          }
        '';
      });

    services.caddy.enable = true;

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.caddy.virtualHosts = {
      "${jellyfinFqdn}".extraConfig = ''
        reverse_proxy http://127.0.0.1:8096
      '';

      "${immichFqdn}".extraConfig = ''
        reverse_proxy http://127.0.0.1:2283
      '';

      "${copypartyFqdn}".extraConfig = ''
        reverse_proxy http://127.0.0.1:3923
      '';

      "${jellyseerrFqdn}".extraConfig = ''
        ${optionalString cfg.services.jellyseerr.protect ''
          import ${config.sops.templates.caddy-basic-auth-jellyseerr.path}
        ''}
        reverse_proxy http://127.0.0.1:5055
      '';

      "${audiobookshelfFqdn}".extraConfig = ''
        ${optionalString cfg.services.audiobookshelf.protect ''
          import ${config.sops.templates.caddy-basic-auth-audiobookshelf.path}
        ''}
        reverse_proxy http://127.0.0.1:9292
      '';

      "${transmissionFqdn}".extraConfig = ''
        ${optionalString cfg.services.transmission.protect ''
          import ${config.sops.templates.caddy-basic-auth-transmission.path}
        ''}
        reverse_proxy http://127.0.0.1:9091 {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-Host {host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };
  };
}
