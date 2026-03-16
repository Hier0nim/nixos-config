{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (config.networking) hostName;
  inherit (config.custom) username;
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets.homelab_ssh_authorized_keys = {
      sopsFile = config.custom.repoPath + "/secrets/${hostName}/ssh.yaml";
      key = "hieronim_authorized_keys";
    };

    sops.templates."authorized-keys-${username}" = {
      content = config.sops.placeholder.homelab_ssh_authorized_keys;
      owner = "root";
      group = "root";
      mode = "0440";
    };

    services.openssh.settings.AuthorizedKeysFile = "/run/secrets/rendered/authorized-keys-%u";
  };
}
