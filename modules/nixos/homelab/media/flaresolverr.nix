{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.media.enable) {
    services.flaresolverr = {
      enable = true;
      port = 8191;
      openFirewall = false;
    };
  };
}
