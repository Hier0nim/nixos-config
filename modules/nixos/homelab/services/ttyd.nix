{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.admin.enable && cfg.services.ttyd.enable) {
    homelab.services.ttyd = {
      expose.enable = lib.mkDefault true;
    };

    services.ttyd = {
      enable = true;
      interface = "127.0.0.1";
      port = 7681;
      # Allow write access (required option)
      writeable = true;
      # Use login as entrypoint (default)
      # No built-in auth - rely on Caddy basicAuth
    };
  };
}
