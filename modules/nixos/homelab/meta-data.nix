{
  proxiedServices = [
    "sonarr"
    "radarr"
    "prowlarr"
    "jellyfin"
    "jellyseerr"
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
    "radarr"
    "prowlarr"
    "jellyseerr"
    "recyclarr"
    "qbittorrent"
  ];

  sharedRoles = {
    media = [
      "sonarr"
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
