{ config, lib, ... }:
let
  cfg = config.services.homepage-dashboard;
  domain = config.services.homelabIngress.domain;
  ingress = config.services.homelabIngress.services;
  card =
    enabled: title: name: description:
    lib.optional enabled {
      ${title} = {
        href = "https://${ingress.${name}.hostname}";
        inherit description;
      };
    };
in
{
  services.homepage-dashboard = {
    enable = lib.mkDefault true;
    allowedHosts = "${domain},127.0.0.1:8082,localhost:8082";
    settings = {
      title = "Pieczarkowo";
      description = "Household apps and homelab status";
      startUrl = "https://${domain}";
      target = "_self";
      headerStyle = "clean";
      hideVersion = true;
      statusStyle = "dot";
      layout = {
        Everyday = {
          style = "row";
          columns = 4;
        };
        Administration = {
          style = "row";
          columns = 4;
        };
      };
    };
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = [
            "/"
            "/data"
          ];
        };
      }
    ];
    services = [
      {
        Everyday =
          card config.services.jellyfin.enable "Jellyfin" "grzybflix" "Films and TV"
          ++ card config.nixflix.seerr.enable "Seerr" "chciejnik" "Request films and series"
          ++ card config.services.audiobookshelf.enable "Audiobookshelf" "audiobooki" "Shared audiobooks"
          ++ card config.services.immich.enable "Immich" "fotki" "Photos"
          ++ card config.services.copyparty.enable "Copyparty" "pliki" "Files"
          ++ card config.services.actual.enable "Actual" "kasa" "Household budget"
          ++ card config.services.paperless.enable "Paperless" "dokumenty" "Household documents"
          ++ card config.services.mealie.enable "Mealie" "przepisy" "Recipes, meals and shopping"
          ++ card config.services.donetick.enable "Donetick" "todo" "Shared chores"
          ++ card config.services.bentopdf.enable "BentoPDF" "pdf" "PDF tools in your browser";
      }
      {
        Administration =
          card config.services.forgejo.enable "Forgejo" "git" "Git and automation"
          ++ card config.services.beszel.hub.enable "Beszel" "monitor" "Detailed server metrics"
          ++ lib.optional config.services.gatus.enable {
            Gatus = {
              href = "https://status.${domain}";
              description = "Availability and uptime. Detailed view requires administrator access.";
              # Caddy fixes pageSize=1 and rejects all other paths; no history reaches the shared widget.
              widget = {
                type = "gatus";
                url = "http://127.0.0.1:8086/gatus-status";
              };
            };
          }
          ++ card config.services.ntfy-sh.enable "ntfy" "ntfy" "Private infrastructure notifications"
          ++ card config.nixflix.radarr.enable "Radarr" "radarr" "Movie administration"
          ++ card config.nixflix.sonarr.enable "Sonarr" "sonarr" "TV administration"
          ++ card config.nixflix.sonarr-anime.enable "Sonarr Anime" "sonarr-anime" "Anime administration"
          ++ card config.nixflix.prowlarr.enable "Prowlarr" "indexers" "Indexer administration"
          ++ card (
            config.virtualisation.oci-containers.containers ? listenarr
          ) "Listenarr" "listenarr" "Audiobook administration"
          ++ card config.nixflix.torrentClients.qbittorrent.enable "qBittorrent" "pobieralnia" "Downloads";
      }
    ];
  };
  systemd.services.homepage-dashboard = lib.mkIf cfg.enable {
    environment.HOSTNAME = "127.0.0.1";
    unitConfig.RequiresMountsFor = [ "/data" ];
  };
  services.homelabIngress.services.dashboard = lib.mkIf cfg.enable {
    hostname = domain;
    upstream = "http://127.0.0.1:8082";
    transport = "direct";
    auth = "proxy";
    group = "household";
  };
}
