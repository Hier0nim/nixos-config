{
  proxiedServices = [
    "sonarr"
    "radarr"
    "prowlarr"
    "bazarr"
    "transmission"
    "jellyfin"
    "jellyseerr"
    "tdarr"
    "audiobookshelf"
    "readarr"
    "readarr-audiobook"
    "immich"
    "copyparty"
    "cockpit"
    "actual"
  ];

  nixarrStateServices = [
    "sonarr"
    "radarr"
    "prowlarr"
    "bazarr"
    "transmission"
    "jellyseerr"
    "audiobookshelf"
    "readarr"
    "readarr-audiobook"
    "recyclarr"
  ];

  sharedRoles = {
    media = [
      "sonarr"
      "radarr"
      "bazarr"
      "transmission"
      "jellyfin"
      "tdarr"
      "audiobookshelf"
      "readarr"
      "readarr-audiobook"
    ];
    photos = [ "immich" ];
    nas = [ "copyparty" ];
  };

  umaskSharedWriters = [
    "transmission"
    "sonarr"
    "radarr"
    "bazarr"
    "readarr"
    "readarr-audiobook"
    "audiobookshelf"
  ];

  immichBindTargets = [
    "upload"
    "thumbs"
    "encoded-video"
    "profile"
  ];
}
