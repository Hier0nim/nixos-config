{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.admin.enable) {
    homelab.services.cockpit.enable = true;
  };
}
