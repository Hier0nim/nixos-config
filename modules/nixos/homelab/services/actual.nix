{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.services.actual.enable) {
    services.actual = {
      enable = true;
      openFirewall = false;
      settings = {
        hostname = "127.0.0.1";
        inherit (cfg.services.actual.upstream) port;
        dataDir = cfg.state.actual;
      };
    };
  };
}
