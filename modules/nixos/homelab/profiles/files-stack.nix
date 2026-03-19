{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.files.enable) {
    homelab.services.copyparty.enable = true;
  };
}
