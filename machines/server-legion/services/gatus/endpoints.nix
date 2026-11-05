{ config, lib }:
let
  http = name: url: conditions: {
    inherit name url conditions;
    group = "Apps";
  };
  frontend =
    name: url: marker:
    http name url [
      "[STATUS] == 200"
      "[BODY] == pat(*${marker}*)"
    ];
  containers = config.virtualisation.oci-containers.containers;
  arrPorts = {
    sonarr = 8989;
    sonarr-anime = 8990;
    radarr = 7878;
    prowlarr = 9696;
  };
in
lib.optional config.services.authelia.instances.homelab.enable (
  http "Authelia" "http://127.0.0.1:9091/api/health" [
    "[STATUS] == 200"
    "[BODY].status == OK"
  ]
)
++ lib.optional config.services.jellyfin.enable (
  http "Jellyfin" "http://127.0.0.1:8096/health" [
    "[STATUS] == 200"
    "[BODY] == Healthy"
  ]
)
++ lib.optional config.services.immich.enable (
  http "Immich" "http://127.0.0.1:2283/api/server/ping" [
    "[STATUS] == 200"
    "[BODY].res == pong"
  ]
)
++ lib.optional config.services.forgejo.enable (
  http "Forgejo" "http://127.0.0.1:3000/api/healthz" [
    "[STATUS] == 200"
    "[BODY].status == pass"
  ]
)
++ lib.optional config.services.beszel.hub.enable (
  http "Beszel" "http://127.0.0.1:8090/api/health" [
    "[STATUS] == 200"
    "[BODY].code == 200"
  ]
)
++ lib.optional config.services.actual.enable (
  http "Actual" "http://127.0.0.1:8086/actual" [
    "[STATUS] == 200"
    "[BODY].status == UP"
  ]
)
++ lib.optional config.services.copyparty.enable (
  frontend "Copyparty" "http://127.0.0.1:8086/copyparty" "copyparty"
)
++ lib.optional config.services.audiobookshelf.enable (
  http "Audiobookshelf" "http://127.0.0.1:8000/ping" [
    "[STATUS] == 200"
    "[BODY].success == true"
  ]
)
++ lib.optional config.nixflix.seerr.enable (
  http "Seerr" "http://127.0.0.1:5055/api/v1/status" [
    "[STATUS] == 200"
    "[BODY].version == pat(*.*.*)"
  ]
)
++ lib.optional (containers ? listenarr) (frontend "Listenarr" "http://127.0.0.1:4545/" "Listenarr")
++ lib.optional config.nixflix.maintainerr.enable (
  frontend "Maintainerr" "http://127.0.0.1:6246/" "Maintainerr"
)
++ lib.concatMap (
  name:
  lib.optional config.nixflix.${name}.enable (
    http name "http://${config.nixflix.${name}.connectionAddress}:${toString arrPorts.${name}}/ping" [
      "[STATUS] == 200"
      "[BODY].status == OK"
    ]
  )
) (builtins.attrNames arrPorts)
++ lib.optional config.nixflix.torrentClients.qbittorrent.enable (
  frontend "qBittorrent" "http://${config.nixflix.torrentClients.qbittorrent.connectionAddress}:8080/"
    "qBittorrent"
)
++ lib.optional config.services.paperless.enable (
  frontend "Paperless" "http://127.0.0.1:28981/accounts/login/" "Paperless"
)
++ lib.optional config.services.mealie.enable (
  http "Mealie" "http://127.0.0.1:9000/api/app/about" [
    "[STATUS] == 200"
    "[BODY].version == pat(*.*.*)"
  ]
)
++ lib.optional (containers ? donetick) (
  http "Donetick" "http://127.0.0.1:2021/api/v1/health" [ "[STATUS] == 200" ]
)
++ lib.optional config.services.bentopdf.enable (
  frontend "BentoPDF" "http://127.0.0.1:8085/" "BentoPDF"
)
++ lib.optional config.services.ntfy-sh.enable (
  http "ntfy" "http://127.0.0.1:2586/v1/health" [
    "[STATUS] == 200"
    "[BODY].healthy == true"
  ]
)
++ lib.optional config.services.homepage-dashboard.enable (
  frontend "Homepage" "http://127.0.0.1:8082/" "Pieczarkowo"
)
++ [
  (http "Gatus" "http://127.0.0.1:8083/health" [
    "[STATUS] == 200"
    "[BODY].status == UP"
  ])
]
