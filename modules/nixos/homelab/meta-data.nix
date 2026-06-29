{
  proxiedServices = [
    "actual"
    "audiobookshelf"
    "cockpit"
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
