{
  proxiedServices = [
    "actual"
    "audiobookshelf"
    "audiobook-imports"
    "beszel"
    "copyparty"
    "enable-actual"
    "immich"
    "jellyfin"
    "prowlarr"
    "qbittorrent"
    "radarr"
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
