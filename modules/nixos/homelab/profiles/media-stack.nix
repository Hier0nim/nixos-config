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
      "sonarr-anime".enable = true;
      radarr.enable = true;
      prowlarr.enable = true;
      prowlarr.indexers.abtorrents.enable = true;
      jellyfin.enable = true;
      audiobookshelf.enable = true;
      seerr.enable = true;
      recyclarr.enable = true;
      qbittorrent.enable = true;
    };
  };
}
