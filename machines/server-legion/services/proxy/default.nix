{
  config,
  lib,
  pkgs,
  ...
}:
let
  cloudflaredCredentialsFile =
    config.clan.core.vars.generators.cloudflare-tunnel.files."credentials.json".path;
in
{
  imports = [ ./ingress.nix ];

  services.caddy = {
    globalConfig = "admin unix//run/caddy/admin.sock";
    # URLs and custom headers can contain credentials, including share capabilities.
    logFormat = ''
      level ERROR
      format filter {
        wrap json
        fields {
          request>uri delete
          request>headers delete
          resp_headers delete
        }
      }
    '';
  };
  # The admin socket and runtime proof imports must be private to Caddy.
  systemd.services.caddy.serviceConfig = {
    RuntimeDirectory = "caddy";
    RuntimeDirectoryMode = "0700";
  };

  clan.core.vars.generators = {
    cloudflare-tunnel = lib.mkIf config.services.homelabIngress.enableTunnel {
      files."credentials.json" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      prompts."credentials.json" = {
        description = "Credentials JSON downloaded for the Cloudflare Tunnel created for server-legion";
        type = "multiline-hidden";
      };
      runtimeInputs = [ pkgs.coreutils ];
      script = ''
        install -m 0400 "$prompts/credentials.json" "$out/credentials.json"
      '';
    };
  };

  services.homelabIngress = {
    enable = true;
    domain = "pieczarkowo.me";
    lanCidrs = [ "192.168.8.0/24" ];
    enableTunnel = true;
    tunnelId = "3352dded-b0ba-4ec2-abc3-d0c4af05bcfb";
    tunnelCredentialsFile = lib.mkIf config.services.homelabIngress.enableTunnel cloudflaredCredentialsFile;
    enableAcme = true;

    services = {
      sonarr = {
        upstream = "http://${config.nixflix.sonarr.connectionAddress}:8989";
        transport = "direct";
        auth = "proxy";
        group = "media-admin";
        integrationApiBypass = true;
      };
      sonarr-anime = {
        upstream = "http://${config.nixflix."sonarr-anime".connectionAddress}:8990";
        transport = "direct";
        auth = "proxy";
        group = "media-admin";
        integrationApiBypass = true;
      };
      radarr = {
        upstream = "http://${config.nixflix.radarr.connectionAddress}:7878";
        transport = "direct";
        auth = "proxy";
        group = "media-admin";
        integrationApiBypass = true;
      };
      indexers = {
        upstream = "http://${config.nixflix.prowlarr.connectionAddress}:9696";
        transport = "direct";
        auth = "proxy";
        group = "media-admin";
      };
      grzybflix = {
        upstream = "http://127.0.0.1:8096";
        transport = "direct";
        auth = "native";
      };
      audiobooki = {
        upstream = "http://127.0.0.1:8000";
        transport = "direct";
        auth = "native";
      };
      listenarr = {
        upstream = "http://127.0.0.1:4545";
        transport = "direct";
        auth = "proxy";
        group = "media-admin";
      };
      chciejnik = {
        upstream = "http://127.0.0.1:5055";
        transport = "direct";
        auth = "native";
      };
      maintainerr = {
        upstream = "http://127.0.0.1:6246";
        transport = "direct";
        auth = "proxy";
        group = "media-admin";
      };
      pobieralnia = {
        upstream = "http://${config.nixflix.torrentClients.qbittorrent.connectionAddress}:8080";
        transport = "direct";
        pathPrefix = "/qbittorrent";
        extraProxyConfig = ''
          header_up -Authorization
          header_up -Proxy-Authorization
          header_up -X-Api-Key
          header_up -X-API-Key
        '';
        auth = "proxy";
        group = "media-admin";
        integrationApiBypass = true;
      };
      fotki = {
        upstream = "http://127.0.0.1:2283";
        transport = "direct";
        auth = "native";
      };
      pliki = {
        upstream = "http://127.0.0.1:3923";
        transport = "direct";
        auth = "proxy";
        group = "household";
        extraProxyConfig = "header_up X-Real-IP {remote_host}";
      };
      monitor = {
        upstream = "http://127.0.0.1:8090";
        transport = "direct";
        auth = "native";
      };
      shell = {
        upstream = "http://127.0.0.1:7681";
        transport = "direct";
        auth = "proxy";
        group = "infra-admin";
      };
      kasa = {
        upstream = "http://127.0.0.1:${toString config.services.actual.settings.port}";
        transport = "direct";
        auth = "native";
      };
      actual-sync = {
        upstream = "http://127.0.0.1:3002";
        transport = "direct";
        auth = "proxy";
        group = "infra-admin";
      };
      git = {
        upstream = "http://127.0.0.1:3000";
        transport = "direct";
        auth = "native";
      };
    };
  };
}
