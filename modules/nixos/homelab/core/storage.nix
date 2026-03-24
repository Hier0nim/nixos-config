{
  config,
  homelabMeta,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (cfg) data;

  mediaEnabled = cfg.profiles.media.enable;
  photosEnabled = cfg.profiles.photos.enable;
  filesEnabled = cfg.profiles.files.enable;

  inherit (homelabMeta) immichBindTargets;
in
{
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${data.root} 0755 root root - -"
      "Z ${data.root} 0755 root root - -"
    ]
    ++ lib.optionals mediaEnabled [
      "d ${data.media} 2775 root media - -"
      "Z ${data.media} 2775 root media - -"
      "d ${data.media}/movies 2775 root media - -"
      "Z ${data.media}/movies 2775 root media - -"
      "d ${data.media}/shows 2775 root media - -"
      "Z ${data.media}/shows 2775 root media - -"
      "d ${data.media}/anime 2775 root media - -"
      "Z ${data.media}/anime 2775 root media - -"
      "d ${data.media}/audiobooks 2775 root media - -"
      "Z ${data.media}/audiobooks 2775 root media - -"
      "d ${data.media}/books 2775 root media - -"
      "Z ${data.media}/books 2775 root media - -"
    ]
    ++ lib.optionals mediaEnabled [
      "d ${data.downloads} 2775 root media - -"
      "Z ${data.downloads} 2775 root media - -"
      "d ${data.downloads}/torrent 2775 root media - -"
      "Z ${data.downloads}/torrent 2775 root media - -"
    ]
    ++ lib.optionals photosEnabled [
      "d ${data.photos} 2770 root photos - -"
      "Z ${data.photos} 2770 root photos - -"
      "d ${data.photos}/library 2770 root photos - -"
      "Z ${data.photos}/library 2770 root photos - -"
      "d ${data.photos}/backups 2770 root photos - -"
      "Z ${data.photos}/backups 2770 root photos - -"
    ]
    ++ lib.optionals photosEnabled (
      # Bind-mount targets for SSD-backed Immich hot data.
      lib.concatMap (name: [
        "d ${data.photos}/${name} 2770 root photos - -"
        "Z ${data.photos}/${name} 2770 root photos - -"
      ]) immichBindTargets
    )
    ++ lib.optionals filesEnabled [
      "d ${data.nas} 2770 root nas - -"
      "Z ${data.nas} 2770 root nas - -"
      "d ${data.nas}/shared 2770 root nas - -"
      "Z ${data.nas}/shared 2770 root nas - -"
      "d ${data.nas}/hieronim 2770 root nas - -"
      "Z ${data.nas}/hieronim 2770 root nas - -"
      "d ${data.nas}/sarka 2770 root nas - -"
      "Z ${data.nas}/sarka 2770 root nas - -"
    ];
  };
}
