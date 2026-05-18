{
  proxiedServices = [
    "sonarr"
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
    "radarr"
    "prowlarr"
    "seerr"
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
