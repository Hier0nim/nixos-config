{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;

  mediaEnabled = cfg.profiles.media.enable;
  downloadsEnabled = cfg.profiles.media.enable;
  photosEnabled = cfg.profiles.photos.enable;
  filesEnabled = cfg.profiles.files.enable;

  mkServiceUserGroups =
    serviceName:
    let
      svc = cfg.services.${serviceName};
    in
    lib.mkIf (svc.enable && svc.dataGroups != [ ]) {
      ${svc.user}.extraGroups = lib.mkAfter svc.dataGroups;
    };
in
{
  config = lib.mkIf cfg.enable {
    users.groups = lib.mkMerge [
      (lib.mkIf mediaEnabled { media = { }; })
      (lib.mkIf downloadsEnabled { downloads = { }; })
      (lib.mkIf photosEnabled { photos = { }; })
      (lib.mkIf filesEnabled { nas = { }; })
    ];

    users.users = lib.mkMerge [
      (mkServiceUserGroups "sonarr")
      (mkServiceUserGroups "radarr")
      (mkServiceUserGroups "prowlarr")
      (mkServiceUserGroups "bazarr")
      (mkServiceUserGroups "transmission")
      (mkServiceUserGroups "jellyfin")
      (mkServiceUserGroups "jellyseerr")
      (mkServiceUserGroups "audiobookshelf")
      (mkServiceUserGroups "readarr")
      (mkServiceUserGroups "readarr-audiobook")
      (mkServiceUserGroups "immich")
      (mkServiceUserGroups "copyparty")
      (mkServiceUserGroups "cockpit")
    ];
  };
}
