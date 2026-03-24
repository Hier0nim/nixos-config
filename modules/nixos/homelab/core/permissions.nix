{
  config,
  homelabMeta,
  lib,
  ...
}:
let
  cfg = config.homelab;

  mediaEnabled = cfg.profiles.media.enable;
  photosEnabled = cfg.profiles.photos.enable;
  filesEnabled = cfg.profiles.files.enable;

  inherit (homelabMeta) umaskSharedWriters;
  inherit (homelabMeta.sharedRoles) media photos nas;

  mediaSharedServices = media;
  photosSharedServices = photos;
  nasSharedServices = nas;
  # Only shared-media writers get UMask=0002; Jellyfin keeps default UMask despite media access.

  mkServiceUserGroups =
    serviceName:
    let
      svc = cfg.services.${serviceName};
    in
    lib.mkIf svc.enable { ${svc.user}.extraGroups = lib.mkAfter svc.dataGroups; };

  mkUmaskOverride =
    serviceName:
    lib.mkIf cfg.services.${serviceName}.enable {
      ${serviceName} = {
        serviceConfig.UMask = lib.mkForce "0002";
      };
    };
in
{
  config = lib.mkIf cfg.enable {
    users.groups = lib.mkMerge [
      (lib.mkIf mediaEnabled { media = { }; })
      (lib.mkIf photosEnabled { photos = { }; })
      (lib.mkIf filesEnabled { nas = { }; })
    ];

    users.users = lib.mkMerge (
      map mkServiceUserGroups (mediaSharedServices ++ photosSharedServices ++ nasSharedServices)
    );

    systemd.services = lib.mkMerge (map mkUmaskOverride umaskSharedWriters);
  };
}
