{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.photos.enable) {
    homelab.services.immich.enable = true;
  };
}
