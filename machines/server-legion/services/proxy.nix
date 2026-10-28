{
  config,
  lib,
  pkgs,
  ...
}:
let
  authFiles = config.clan.core.vars.generators.caddy-auth.files;

  authImports = {
    media-admin = "import ${authFiles."media-admin.caddy".path}";
    infra-admin = "import ${authFiles."infra-admin.caddy".path}";
  };

  stripAuthHeaders = ''
    header_up -Authorization
    header_up -Proxy-Authorization
    header_up -X-Api-Key
    header_up -X-API-Key
  '';

  mkProxy =
    {
      port,
      host ? "127.0.0.1",
      auth ? null,
      apiBypass ? false,
      pathPrefix ? null,
      redirectToPrefix ? false,
      stripAuthorizationHeader ? false,
      extraProxyConfig ? "",
    }:
    let
      upstream = "${host}:${toString port}";
      proxyConfig = lib.concatStringsSep "\n" (
        lib.filter (value: value != "") [
          extraProxyConfig
          (lib.optionalString stripAuthorizationHeader stripAuthHeaders)
        ]
      );
      reverseProxy =
        if pathPrefix == null then
          ''
            reverse_proxy ${upstream} {
              ${proxyConfig}
            }
          ''
        else
          ''
            reverse_proxy ${pathPrefix}/* ${upstream} {
              ${proxyConfig}
            }
          '';
      authImport = if auth == null then "" else authImports.${auth};
      apiPrefix = if pathPrefix == null then "/" else "${pathPrefix}/";
      apiHandler = lib.optionalString apiBypass ''
        @api path ${apiPrefix}api*
        handle @api {
          reverse_proxy ${upstream} {
            ${proxyConfig}
          }
        }
      '';
      defaultHandler =
        if apiBypass then
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
    in
    ''
      ${lib.optionalString (pathPrefix != null && redirectToPrefix) "redir / ${pathPrefix}/"}
      ${apiHandler}
      ${defaultHandler}
    '';

  virtualHosts = {
    "sonarr.pieczarkowo.me".extraConfig = mkProxy {
      host = config.nixflix.sonarr.connectionAddress;
      port = 8989;
      auth = "media-admin";
      apiBypass = true;
    };
    "sonarr-anime.pieczarkowo.me".extraConfig = mkProxy {
      host = config.nixflix."sonarr-anime".connectionAddress;
      port = 8990;
      auth = "media-admin";
      apiBypass = true;
    };
    "radarr.pieczarkowo.me".extraConfig = mkProxy {
      host = config.nixflix.radarr.connectionAddress;
      port = 7878;
      auth = "media-admin";
      apiBypass = true;
    };
    "indexers.pieczarkowo.me".extraConfig = mkProxy {
      host = config.nixflix.prowlarr.connectionAddress;
      port = 9696;
      auth = "media-admin";
    };
    "grzybflix.pieczarkowo.me".extraConfig = mkProxy {
      port = 8096;
    };
    "audiobooki.pieczarkowo.me".extraConfig = mkProxy {
      port = 8000;
    };
    "listenarr.pieczarkowo.me".extraConfig = mkProxy {
      port = 4545;
      auth = "media-admin";
    };
    "chciejnik.pieczarkowo.me".extraConfig = mkProxy {
      port = 5055;
    };
    "maintainerr.pieczarkowo.me".extraConfig = mkProxy {
      port = 6246;
      auth = "media-admin";
    };
    "pobieralnia.pieczarkowo.me".extraConfig = mkProxy {
      host = config.nixflix.torrentClients.qbittorrent.connectionAddress;
      port = 8080;
      auth = "media-admin";
      apiBypass = true;
      pathPrefix = "/qbittorrent";
      redirectToPrefix = true;
      stripAuthorizationHeader = true;
    };
    "fotki.pieczarkowo.me".extraConfig = mkProxy {
      port = 2283;
    };
    "pliki.pieczarkowo.me".extraConfig = mkProxy {
      port = 3923;
      extraProxyConfig = "header_up X-Real-IP {remote_host}";
    };
    "monitor.pieczarkowo.me".extraConfig = mkProxy {
      port = 8090;
    };
    "shell.pieczarkowo.me".extraConfig = mkProxy {
      port = 7681;
      auth = "infra-admin";
    };
    "kasa.pieczarkowo.me".extraConfig = mkProxy {
      port = 3100;
    };
    "actual-sync.pieczarkowo.me".extraConfig = mkProxy {
      port = 3002;
      auth = "infra-admin";
    };
    "git.pieczarkowo.me".extraConfig = mkProxy {
      port = 3000;
    };
  };
in
{
  clan.core.vars.generators.caddy-auth = {
    files = {
      "media-admin.caddy" = {
        owner = "caddy";
        group = "caddy";
        mode = "0400";
      };
      "infra-admin.caddy" = {
        owner = "caddy";
        group = "caddy";
        mode = "0400";
      };
    };
    prompts = {
      media-admin = {
        description = "Caddy basic-auth snippet for media services";
        type = "multiline-hidden";
      };
      infra-admin = {
        description = "Caddy basic-auth snippet for infrastructure services";
        type = "multiline-hidden";
      };
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      install -m 0400 "$prompts/media-admin" "$out/media-admin.caddy"
      install -m 0400 "$prompts/infra-admin" "$out/infra-admin.caddy"
    '';
  };

  services.caddy = {
    enable = true;
    inherit virtualHosts;
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
