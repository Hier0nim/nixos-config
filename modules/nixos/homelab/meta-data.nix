{
  proxiedServices = [
    "actual"
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

  sharedRoles = {
    media = [
      "jellyfin"
      "qbittorrent"
      "radarr"
      "sonarr"
      "sonarr-anime"
      "tdarr"
    ];
    photos = [ "immich" ];
    nas = [ "copyparty" ];
  };

  umaskSharedWriters = [
    "prowlarr"
    "qbittorrent"
    "radarr"
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
