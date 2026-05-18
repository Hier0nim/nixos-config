{
  proxiedServices = [
    "sonarr"
    "sonarr-anime"
    "radarr"
    "prowlarr"
    "jellyfin"
    "seerr"
    "tdarr"
    "immich"
    "copyparty"
    "cockpit"
    "actual"
    "enable-actual"
    "qbittorrent"
  ];

  nixflixStateServices = [
    "sonarr"
    "sonarr-anime"
    "radarr"
    "prowlarr"
    "seerr"
    "recyclarr"
    "qbittorrent"
  ];

  sharedRoles = {
    media = [
      "sonarr"
      "sonarr-anime"
      "radarr"
      "jellyfin"
      "tdarr"
      "qbittorrent"
    ];
    photos = [ "immich" ];
    nas = [ "copyparty" ];
  };

  umaskSharedWriters = [
    "sonarr"
    "sonarr-anime"
    "radarr"
    "qbittorrent"
  ];

  immichBindTargets = [
    "upload"
    "thumbs"
    "encoded-video"
    "profile"
  ];
}
