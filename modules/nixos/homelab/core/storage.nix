{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (cfg) data;

  mediaEnabled = cfg.profiles.media.enable;
  downloadsEnabled = cfg.profiles.media.enable;
  photosEnabled = cfg.profiles.photos.enable;
  filesEnabled = cfg.profiles.files.enable;
in
{
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${data.root} 0755 root root - -"
      "Z ${data.root} 0755 root root - -"
      "d ${data.appdata} 0755 root root - -"
      "Z ${data.appdata} 0755 root root - -"
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
    ++ lib.optionals downloadsEnabled [
      "d ${data.downloads} 2775 root downloads - -"
      "Z ${data.downloads} 2775 root downloads - -"
      "d ${data.downloads}/torrent 2775 root downloads - -"
      "Z ${data.downloads}/torrent 2775 root downloads - -"
      "d ${data.downloads}/torrent/incomplete 2775 root downloads - -"
      "Z ${data.downloads}/torrent/incomplete 2775 root downloads - -"
      "d ${data.downloads}/torrent/complete 2775 root downloads - -"
      "Z ${data.downloads}/torrent/complete 2775 root downloads - -"
      "d ${data.downloads}/torrent/complete/movies-radarr 2775 root downloads - -"
      "Z ${data.downloads}/torrent/complete/movies-radarr 2775 root downloads - -"
      "d ${data.downloads}/torrent/complete/tv-sonarr 2775 root downloads - -"
      "Z ${data.downloads}/torrent/complete/tv-sonarr 2775 root downloads - -"
      "d ${data.downloads}/torrent/complete/books-readarr 2775 root downloads - -"
      "Z ${data.downloads}/torrent/complete/books-readarr 2775 root downloads - -"
      "d ${data.downloads}/torrent/watch 2775 root downloads - -"
      "Z ${data.downloads}/torrent/watch 2775 root downloads - -"
    ]
    ++ lib.optionals photosEnabled [
      "d ${data.photos} 2770 root photos - -"
      "Z ${data.photos} 2770 root photos - -"
    ]
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
