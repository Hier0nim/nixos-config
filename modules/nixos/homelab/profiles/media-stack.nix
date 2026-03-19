{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.media.enable) {
    homelab.services = {
      sonarr.enable = true;
      radarr.enable = true;
      prowlarr.enable = true;
      bazarr.enable = true;
      transmission.enable = true;
      jellyfin.enable = true;
      jellyseerr.enable = true;
      audiobookshelf.enable = true;
      readarr.enable = true;
      "readarr-audiobook".enable = true;
    };
  };
}
