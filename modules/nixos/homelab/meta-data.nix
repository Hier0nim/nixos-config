{
  proxiedServices = [
    "actual"
    "audiobookshelf"
    "audiobook-imports"
    "beszel"
    "copyparty"
    "enable-actual"
    "forgejo"
    "immich"
    "jellyfin"
    "maintainerr"
    "prowlarr"
    "qbittorrent"
    "radarr"
    "remote-pi-relay"
    "seerr"
    "sonarr"
    "sonarr-anime"
    "tdarr"
    "ttyd"
  ];

  nixflixStateServices = [
    "prowlarr"
    "qbittorrent"
    "radarr"
    "recyclarr"
    "seerr"
    "maintainerr"
    "sonarr"
    "sonarr-anime"
  ];

  immichBindTargets = [
    "upload"
    "thumbs"
    "encoded-video"
    "profile"
  ];
}
