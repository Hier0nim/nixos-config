{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf cfg.enable {
    # Backup policy (skeleton):
    # - Back up: /data/photos, /data/nas
    # - Maybe later: /data/media/ebooks, /data/media/audiobooks
    # - Do not back up: /data/downloads, recreatable media libraries
  };
}
