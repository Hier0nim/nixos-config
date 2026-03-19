{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (config.networking) hostName;
  inherit (lib) mkIf optionalAttrs optionalString;
  inherit (config.custom) repoPath;

  caddySecretsFile = "${repoPath}/secrets/${hostName}/caddy.yaml";

  mkAuth =
    name: group:
    let
      inherit (group) secretRef;
    in
    {
      secrets = {
        "${secretRef}_user" = {
          sopsFile = caddySecretsFile;
          key = "${secretRef}_user";
          owner = "root";
          group = "keys";
          mode = "0440";
        };
        "${secretRef}_hash" = {
          sopsFile = caddySecretsFile;
          key = "${secretRef}_hash";
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
              ${config.sops.placeholder."${secretRef}_user"} ${config.sops.placeholder."${secretRef}_hash"}
            }
          '';
        };
      };
    };

  inherit (cfg.auth) groups;
  authNames = builtins.attrNames groups;
  authAttrs = builtins.map (name: mkAuth name groups.${name}) authNames;
  authSecrets = lib.foldl' (acc: item: acc // item.secrets) { } authAttrs;
  authTemplates = lib.foldl' (acc: item: acc // item.template) { } authAttrs;

  mkReverseProxy =
    upstream: extraConfig:
    if extraConfig == "" then
      "reverse_proxy ${upstream}"
    else
      ''
        reverse_proxy ${upstream} {
          ${extraConfig}
        }
      '';

  mkPrefixedProxy =
    prefix: upstream: extraConfig:
    if extraConfig == "" then
      "reverse_proxy ${prefix}/* ${upstream}"
    else
      ''
        reverse_proxy ${prefix}/* ${upstream} {
          ${extraConfig}
        }
      '';

  mkServiceVhost =
    name: svc:
    let
      fqdn = "${svc.expose.subdomain}.${cfg.domain}";
      upstream = "http://${svc.upstream.host}:${toString svc.upstream.port}";
      authImport =
        optionalString (svc.auth.group != null)
          "import ${config.sops.templates."caddy-basic-auth-${svc.auth.group}".path}";
      reverseProxy =
        if svc.expose.pathPrefix == null then
          mkReverseProxy upstream svc.expose.reverseProxyExtraConfig
        else
          mkPrefixedProxy svc.expose.pathPrefix upstream svc.expose.reverseProxyExtraConfig;
      apiBypassConfig = optionalString svc.auth.bypassForApi ''
        @api path ${optionalString (svc.expose.pathPrefix != null) "${svc.expose.pathPrefix}/"}api/*
        handle @api {
          ${mkReverseProxy upstream svc.expose.reverseProxyExtraConfig}
        }
      '';
      baseHandle =
        if svc.auth.bypassForApi then
          ''
            handle {
              ${authImport}
              ${reverseProxy}
            }
          ''
        else
          ''
            ${authImport}
            ${reverseProxy}
          '';
      redirectConfig = optionalString (svc.expose.pathPrefix != null && svc.expose.redirectToPrefix) ''
        redir / ${svc.expose.pathPrefix}/
      '';
    in
    optionalAttrs (svc.enable && svc.expose.enable) {
      "${fqdn}".extraConfig = ''
        ${redirectConfig}
        ${apiBypassConfig}
        ${baseHandle}
      '';
    };
in
{
  config = mkIf (cfg.enable && cfg.proxy.enable) {
    users.users.caddy.extraGroups = [ "keys" ];

    sops.secrets = authSecrets;
    sops.templates = authTemplates;

    services.caddy.enable = true;

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.caddy.virtualHosts =
      mkServiceVhost "sonarr" cfg.services.sonarr
      // mkServiceVhost "radarr" cfg.services.radarr
      // mkServiceVhost "prowlarr" cfg.services.prowlarr
      // mkServiceVhost "bazarr" cfg.services.bazarr
      // mkServiceVhost "transmission" cfg.services.transmission
      // mkServiceVhost "jellyfin" cfg.services.jellyfin
      // mkServiceVhost "jellyseerr" cfg.services.jellyseerr
      // mkServiceVhost "audiobookshelf" cfg.services.audiobookshelf
      // mkServiceVhost "readarr" cfg.services.readarr
      // mkServiceVhost "readarr-audiobook" cfg.services."readarr-audiobook"
      // mkServiceVhost "immich" cfg.services.immich
      // mkServiceVhost "copyparty" cfg.services.copyparty
      // mkServiceVhost "cockpit" cfg.services.cockpit;
  };
}
