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

  mkAuth = name: {
    secrets = {
      "${name}_user" = {
        sopsFile = caddySecretsFile;
        key = "${name}_user";
        owner = "caddy";
        group = "caddy";
        mode = "0400";
      };
      "${name}_hash" = {
        sopsFile = caddySecretsFile;
        key = "${name}_hash";
        owner = "caddy";
        group = "caddy";
        mode = "0400";
      };
    };
    template = {
      "caddy-basic-auth-${name}".content = ''
        basic_auth {
          ${config.sops.placeholder."${name}_user"} ${config.sops.placeholder."${name}_hash"}
        }
      '';
    };
  };

  jellyseerrAuth = mkAuth "jellyseerr";
  audiobookshelfAuth = mkAuth "audiobookshelf";
  transmissionAuth = mkAuth "transmission";
in
{
  config = mkIf (cfg.enable && cfg.proxy.enable) {
    sops.secrets =
      (optionalAttrs cfg.services.jellyseerr.protect jellyseerrAuth.secrets)
      // (optionalAttrs cfg.services.audiobookshelf.protect audiobookshelfAuth.secrets)
      // (optionalAttrs cfg.services.transmission.protect transmissionAuth.secrets);

    sops.templates =
      (optionalAttrs cfg.services.jellyseerr.protect jellyseerrAuth.template)
      // (optionalAttrs cfg.services.audiobookshelf.protect audiobookshelfAuth.template)
      // (optionalAttrs cfg.services.transmission.protect transmissionAuth.template);

    services.caddy = {
      enable = true;
    };

    services.caddy.virtualHosts = {
      "${jellyfinFqdn}".extraConfig = ''
        reverse_proxy http://127.0.0.1:8096
      '';

      "${immichFqdn}".extraConfig = ''
        reverse_proxy http://127.0.0.1:2283
      '';

      "${copypartyFqdn}".extraConfig = ''
        reverse_proxy http://127.0.0.1:3923 {
          header_up Host {host}
          header_up X-Forwarded-Host {host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote_host}
          header_up X-Real-IP {remote_host}
        }
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

        redir / /transmission/

        reverse_proxy /transmission/* http://127.0.0.1:9091 {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-Host {host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };
  };
}
