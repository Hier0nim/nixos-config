{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (config.networking) hostName;
  inherit (lib) mkIf optionalAttrs optionalString;

  caddySecretsFile = "${config.custom.repoPath}/secrets/${hostName}/caddy.yaml";

  jellyfinFqdn = "${cfg.services.jellyfin.subdomain}.${cfg.domain}";
  immichFqdn = "${cfg.services.immich.subdomain}.${cfg.domain}";
  copypartyFqdn = "${cfg.services.copyparty.subdomain}.${cfg.domain}";
  jellyseerrFqdn = "${cfg.services.jellyseerr.subdomain}.${cfg.domain}";
  audiobookshelfFqdn = "${cfg.services.audiobookshelf.subdomain}.${cfg.domain}";
  transmissionFqdn = "${cfg.services.transmission.subdomain}.${cfg.domain}";
  grafanaFqdn = "${cfg.services.grafana.subdomain}.${cfg.domain}";
  cockpitFqdn = "${cfg.services.cockpit.subdomain}.${cfg.domain}";

  grafanaEnabled = cfg.monitoring.enable && cfg.monitoring.grafana.enable;
  cockpitEnabled = cfg.monitoring.enable && cfg.monitoring.cockpit.enable;

  mkAuth = name: {
    secrets = {
      "${name}_user" = {
        sopsFile = caddySecretsFile;
        key = "${name}_user";
        owner = "root";
        group = "keys";
        mode = "0440";
      };
      "${name}_hash" = {
        sopsFile = caddySecretsFile;
        key = "${name}_hash";
        owner = "root";
        group = "keys";
        mode = "0440";
      };
    };

    template = {
      "caddy-basic-auth-${name}" = {
        owner = "root";
        group = "keys";
        mode = "0440";
        content = ''
          basic_auth {
            ${config.sops.placeholder."${name}_user"} ${config.sops.placeholder."${name}_hash"}
          }
        '';
      };
    };
  };

  jellyseerrAuth = mkAuth "jellyseerr";
  audiobookshelfAuth = mkAuth "audiobookshelf";
  transmissionAuth = mkAuth "transmission";
  grafanaAuth = mkAuth "grafana";
  cockpitAuth = mkAuth "cockpit";
in
{
  config = mkIf (cfg.enable && cfg.proxy.enable) {
    users.users.caddy.extraGroups = [ "keys" ];

    sops.secrets =
      (optionalAttrs cfg.services.jellyseerr.protect jellyseerrAuth.secrets)
      // (optionalAttrs cfg.services.audiobookshelf.protect audiobookshelfAuth.secrets)
      // (optionalAttrs cfg.services.transmission.protect transmissionAuth.secrets)
      // (optionalAttrs (grafanaEnabled && cfg.services.grafana.protect) grafanaAuth.secrets)
      // (optionalAttrs (cockpitEnabled && cfg.services.cockpit.protect) cockpitAuth.secrets);

    sops.templates =
      (optionalAttrs cfg.services.jellyseerr.protect jellyseerrAuth.template)
      // (optionalAttrs cfg.services.audiobookshelf.protect audiobookshelfAuth.template)
      // (optionalAttrs cfg.services.transmission.protect transmissionAuth.template)
      // (optionalAttrs (grafanaEnabled && cfg.services.grafana.protect) grafanaAuth.template)
      // (optionalAttrs (cockpitEnabled && cfg.services.cockpit.protect) cockpitAuth.template);

    services.caddy = {
      enable = true;
    };

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
        reverse_proxy http://127.0.0.1:3923 {
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

        reverse_proxy /audiobookshelf/* http://127.0.0.1:9292
        redir / /audiobookshelf/
      '';

      "${transmissionFqdn}".extraConfig = ''
        ${optionalString cfg.services.transmission.protect ''
          import ${config.sops.templates.caddy-basic-auth-transmission.path}
        ''}

        redir / /transmission/

        reverse_proxy /transmission/* http://127.0.0.1:9091
      '';
    }
    // optionalAttrs grafanaEnabled {
      "${grafanaFqdn}".extraConfig = ''
        ${optionalString cfg.services.grafana.protect ''
          import ${config.sops.templates.caddy-basic-auth-grafana.path}
        ''}
        reverse_proxy http://127.0.0.1:3000
      '';
    }
    // optionalAttrs cockpitEnabled {
      "${cockpitFqdn}".extraConfig = ''
        reverse_proxy http://127.0.0.1:9090 {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
    };
  };
}
