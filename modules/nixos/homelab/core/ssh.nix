{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (config.custom) username;
in
{
  config = lib.mkIf cfg.enable {
    users.users.${username}.openssh.authorizedKeys.keys = cfg.ssh.authorizedKeys;
  };
}
