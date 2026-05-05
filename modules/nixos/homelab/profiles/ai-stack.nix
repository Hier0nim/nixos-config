{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.ai.enable) {
    homelab.services."llama-cpp-agent".enable = true;
  };
}
