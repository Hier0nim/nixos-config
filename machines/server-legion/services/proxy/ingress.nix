{ config, lib, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.services.homelabIngress;
  groupType = types.enum [
    "media-admin"
    "infra-admin"
    "household"
    "finance"
  ];

  serviceModule = {
    options = {
      upstream = mkOption {
        type = types.str;
        description = "Full HTTP or HTTPS backend URL, including its port.";
      };
      transport = mkOption {
        type = types.enum [
          "direct"
          "tunnel"
        ];
        description = "Public transport; tunnel origins also permit the configured LAN peers.";
      };
      auth = mkOption {
        type = types.enum [
          "native"
          "proxy"
        ];
        description = "Application-native authentication or Authelia forward auth.";
      };
      group = mkOption {
        type = types.nullOr groupType;
        default = null;
        description = "Admission group for Authelia. Application permissions remain separate.";
      };
      integrationApiBypass = mkOption {
        type = types.bool;
        default = false;
        description = "Let API paths bypass the browser gate; the backend must enforce native key or session authentication.";
      };
      pathPrefix = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Mount the backend under this prefix; redirect the site root and strip the prefix upstream.";
      };
      extraProxyConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Service-specific Caddy reverse_proxy directives, such as qBittorrent header handling.";
      };
    };
  };

  # Render a service's Caddy settings. Origin checks must precede all handlers and redirects.
  mkRoute =
    service:
    let
      auth = lib.optionalString (service.auth == "proxy") ''
        forward_auth 127.0.0.1:9091 {
          uri /api/authz/forward-auth
          # Old Basic credentials must not override the browser's session.
          header_up -Authorization
          header_up -Proxy-Authorization
        }
      '';
      reverseProxy = ''
        reverse_proxy ${service.upstream} {
          ${service.extraProxyConfig}
        }
      '';
      stripPrefix = lib.optionalString (
        service.pathPrefix != null
      ) "uri strip_prefix ${service.pathPrefix}";
      proxy =
        if service.pathPrefix == null then
          reverseProxy
        else
          ''
            @prefixed path ${service.pathPrefix}/*
            handle @prefixed {
              ${stripPrefix}
              ${reverseProxy}
            }
          '';
      apiPrefix = if service.pathPrefix == null then "/" else "${service.pathPrefix}/";
      handlers =
        if service.integrationApiBypass then
          ''
            @api path ${apiPrefix}api ${apiPrefix}api/*
            handle @api {
              ${stripPrefix}
              ${reverseProxy}
            }
            handle {
              ${auth}
              ${proxy}
            }
          ''
        else
          ''
            ${auth}
            ${proxy}
          '';
    in
    {
      useACMEHost = if cfg.enableAcme then cfg.domain else null;
      # NixOS otherwise creates an unfiltered per-host access log.
      logFormat = null;
      extraConfig = ''
        route {
          ${lib.optionalString (cfg.enableTunnel && service.transport == "tunnel") ''
            @outside-lan not remote_ip 127.0.0.1 ::1 ${lib.concatStringsSep " " cfg.lanCidrs}
            respond @outside-lan 403
          ''}
          ${lib.optionalString (service.pathPrefix != null) "redir / ${service.pathPrefix}/"}
          ${handlers}
        }
      '';
    };
  hostnames = lib.mapAttrs (name: _: "${name}.${cfg.domain}") cfg.services;
  tunnelServices = lib.filterAttrs (_: service: service.transport == "tunnel") cfg.services;
  inventory = lib.concatStringsSep "\n" (
    [ "hostname\ttransport-target\ttunnel-active\tproxy-auth\tgroup\tupstream" ]
    ++ lib.mapAttrsToList (
      name: service:
      lib.concatStringsSep "\t" [
        hostnames.${name}
        service.transport
        (lib.boolToString (cfg.enableTunnel && service.transport == "tunnel"))
        service.auth
        (if service.group == null then "" else service.group)
        service.upstream
      ]
    ) cfg.services
  );
in
{
  options.services.homelabIngress = {
    enable = lib.mkEnableOption "the homelab Caddy service registry";
    domain = mkOption {
      type = types.str;
      default = "pieczarkowo.me";
      description = "Base domain for service hostnames.";
    };
    lanCidrs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Verified LAN client networks permitted at tunnel origins, using the actual connection peer.";
    };
    enableTunnel = mkOption {
      type = types.bool;
      default = false;
      description = "Activate the externally created tunnel and its public-origin restrictions together.";
    };
    tunnelId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "UUID of the locally managed tunnel, supplied after external bootstrap.";
    };
    tunnelCredentialsFile = mkOption {
      type = types.nullOr types.externalPath;
      default = null;
      description = "Runtime Clan Vars path to tunnel credentials JSON.";
    };
    enableAcme = mkOption {
      type = types.bool;
      default = false;
      description = "Use the prepared DNS-01 wildcard certificate for Caddy.";
    };
    services = mkOption {
      type = types.attrsOf (types.submodule serviceModule);
      default = { };
      description = "Explicit service upstreams, target transports, and active proxy authentication.";
    };
  };

  config = mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion =
              !cfg.enableTunnel
              || (
                cfg.tunnelId != null
                &&
                  builtins.match "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" cfg.tunnelId
                  != null
                && cfg.tunnelCredentialsFile != null
                && cfg.lanCidrs != [ ]
              );
            message = "Tunnel activation requires its UUID, credentials, and verified LAN client networks.";
          }
        ]
        ++ lib.concatLists (
          lib.mapAttrsToList (name: service: [
            {
              assertion = builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null && name != "home";
              message = "Ingress label '${name}' is invalid or reserved.";
            }
            {
              assertion = lib.hasPrefix "http://" service.upstream || lib.hasPrefix "https://" service.upstream;
              message = "${name} requires a full HTTP or HTTPS backend URL.";
            }
            {
              assertion = (service.auth == "native") == (service.group == null);
              message = "${name} must set a group exactly when proxy authentication is selected.";
            }
            {
              assertion = service.auth != "proxy" || (config.services.authelia.instances.homelab.enable or false);
              message = "${name} requires the enabled homelab Authelia instance.";
            }
            {
              assertion = !service.integrationApiBypass || service.auth != "native";
              message = "${name}: an API exception requires a browser gate and verified native API authentication.";
            }
            {
              assertion =
                service.pathPrefix == null || builtins.match "/[a-zA-Z0-9_-]+" service.pathPrefix != null;
              message = "${name} pathPrefix must be one literal path component without a trailing slash.";
            }
            {
              assertion = name != "auth" || service.auth == "native";
              message = "The Authelia portal must not authenticate against itself.";
            }
          ]) cfg.services
        );

        services.caddy = {
          enable = true;
          virtualHosts = lib.mapAttrs' (
            name: service: lib.nameValuePair hostnames.${name} (mkRoute service)
          ) cfg.services;
        };
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];
        environment.etc."homelab-ingress/services.tsv".text = inventory + "\n";
      }
      (mkIf (cfg.enableTunnel && cfg.tunnelId != null && cfg.tunnelCredentialsFile != null) {
        services.cloudflared = {
          enable = true;
          tunnels.${cfg.tunnelId} = {
            credentialsFile = cfg.tunnelCredentialsFile;
            default = "http_status:404";
            ingress = lib.mapAttrs' (
              name: _:
              lib.nameValuePair hostnames.${name} {
                service = "https://127.0.0.1:443";
                originRequest = {
                  originServerName = hostnames.${name};
                  httpHostHeader = hostnames.${name};
                  noTLSVerify = false;
                };
              }
            ) tunnelServices;
          };
        };
      })
    ]
  );
}
