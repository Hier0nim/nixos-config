{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  homelabMeta = import ../meta-data.nix;
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

  proxiedServices =
    homelabMeta.proxiedServices
    ++
      lib.optionals
        (
          cfg.services."llama-cpp-agent".enable
          && (
            cfg.services."llama-cpp-agent".expose.enable || cfg.services."llama-cpp-agent".expose.api.enable
          )
        )
        [
          "llama-cpp-agent"
        ];

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

  mkVhost =
    {
      svc,
      subdomain,
      authGroup ? svc.auth.group,
      pathPrefix ? svc.expose.pathPrefix,
      redirectToPrefix ? svc.expose.redirectToPrefix,
      reverseProxyExtraConfig ? svc.expose.reverseProxyExtraConfig,
      bypassForApi ? svc.auth.bypassForApi,
    }:
    let
      fqdn = "${subdomain}.${cfg.domain}";
      upstream = "${svc.upstream.scheme}://${svc.upstream.host}:${toString svc.upstream.port}";
      authImport =
        optionalString (authGroup != null)
          "import ${config.sops.templates."caddy-basic-auth-${authGroup}".path}";
      reverseProxy =
        if pathPrefix == null then
          mkReverseProxy upstream reverseProxyExtraConfig
        else
          mkPrefixedProxy pathPrefix upstream reverseProxyExtraConfig;
      apiBypassConfig =
        let
          apiPrefix = if pathPrefix != null then "${pathPrefix}/" else "/";
        in
        optionalString bypassForApi ''
          @api path ${apiPrefix}api/*
          handle @api {
            ${mkReverseProxy upstream reverseProxyExtraConfig}
          }
        '';
      baseHandle =
        if bypassForApi then
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
      redirectConfig = optionalString (pathPrefix != null && redirectToPrefix) ''
        redir / ${pathPrefix}/
      '';
    in
    {
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

    services.caddy.virtualHosts = lib.foldl' (
      acc: name:
      let
        svc = cfg.services.${name};
        baseVhost = optionalAttrs (svc.enable && svc.expose.enable) (mkVhost {
          inherit svc;
          inherit (svc.expose) subdomain;
        });
        apiVhost =
          optionalAttrs (name == "llama-cpp-agent" && svc.enable && svc.expose.api.enable)
            (mkVhost {
              inherit svc;
              inherit (svc.expose.api) subdomain;
              authGroup = null;
              pathPrefix = null;
              redirectToPrefix = false;
              reverseProxyExtraConfig = "";
              bypassForApi = false;
            });
      in
      acc // baseVhost // apiVhost
    ) { } proxiedServices;
  };
}
