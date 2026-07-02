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
  homelabMeta = import ../meta-data.nix;

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
  authNames = lib.attrNames groups;
  authAttrs = lib.map (name: mkAuth name groups.${name}) authNames;
  authSecrets = lib.foldl' (acc: item: acc // item.secrets) { } authAttrs;
  authTemplates = lib.foldl' (acc: item: acc // item.template) { } authAttrs;
  caddyQuote = _value: ""; # kept for compatibility
  appendCaddyConfig =
    first: second:
    lib.concatStringsSep "\n" (
      lib.filter (value: value != "") [
        first
        second
      ]
    );
  inherit (homelabMeta) proxiedServices;

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
  stripUpstreamAuthHeaders = ''
    header_up -Authorization
    header_up -Proxy-Authorization
    header_up -X-Api-Key
    header_up -X-API-Key
  '';

  mkVhost =
    {
      svc,
      subdomain,
      rootRedirect ? null,
    }:
    let
      fqdn = "${subdomain}.${cfg.domain}";
      upstream = "${svc.upstream.scheme}://${svc.upstream.host}:${toString svc.upstream.port}";
      tlsConfig = optionalString (svc.expose.tls != null) ''
        tls ${svc.expose.tls.certFile} ${svc.expose.tls.keyFile}
      '';
      authImport =
        optionalString (svc.auth.group != null)
          "import ${config.sops.templates."caddy-basic-auth-${svc.auth.group}".path}";
      proxyExtraConfig = appendCaddyConfig svc.expose.reverseProxyExtraConfig (
        optionalString svc.auth.stripAuthorizationHeader stripUpstreamAuthHeaders
      );
      reverseProxy =
        if svc.expose.pathPrefix == null then
          mkReverseProxy upstream proxyExtraConfig
        else
          mkPrefixedProxy svc.expose.pathPrefix upstream proxyExtraConfig;
      apiBypassConfig =
        let
          apiPrefix = if svc.expose.pathPrefix != null then "${svc.expose.pathPrefix}/" else "/";
        in
        optionalString svc.auth.bypassForApi ''
          @api path ${apiPrefix}api*
          handle @api {
            ${mkReverseProxy upstream proxyExtraConfig}
          }
        '';
      baseHandle =
        if rootRedirect != null then
          ''
            handle / {
              ${authImport}
              redir * ${caddyQuote rootRedirect}
            }

            handle {
              ${authImport}
              ${reverseProxy}
            }
          ''
        else if svc.auth.bypassForApi then
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
      # IP allowlist: if allowedCIDRs is set, wrap in @allowed matcher
      cidrs = svc.expose.allowedCIDRs;
      ipAllowConfig = optionalString (cidrs != [ ]) ''
        @allowed remote_ip ${lib.concatStringsSep " " cidrs}
        handle @allowed {
          ${baseHandle}
        }

        respond 404
      '';
      finalHandle = if cidrs != [ ] then ipAllowConfig else baseHandle;
    in
    {
      "${fqdn}".extraConfig = ''
        ${tlsConfig}
        ${redirectConfig}
        ${apiBypassConfig}
        ${finalHandle}
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

    services.caddy.virtualHosts = lib.foldl' (
      acc: name:
      let
        svc = cfg.services.${name};
        baseVhost = optionalAttrs (svc.enable && svc.expose.enable) (mkVhost {
          inherit svc;
          subdomain = svc.expose.subdomain;
        });
      in
      acc // baseVhost
    ) { } proxiedServices;
  };
}
