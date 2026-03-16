{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (config.networking) hostName;
  copypartyUser = config.services.copyparty.user;
  copypartyGroup = config.services.copyparty.group;
in
{
  config = lib.mkIf (cfg.enable && cfg.files.enable) {
    sops.secrets.copyparty_hieronim_password = {
      sopsFile = config.custom.repoPath + "/secrets/${hostName}/copyparty.yaml";
      key = "hieronim_password";
      # statix:ignore
      owner = copypartyUser;
      # statix:ignore
      group = copypartyGroup;
      mode = "0400";
    };

    sops.secrets.copyparty_sarka_password = {
      sopsFile = config.custom.repoPath + "/secrets/${hostName}/copyparty.yaml";
      key = "sarka_password";
      # statix:ignore
      owner = copypartyUser;
      # statix:ignore
      group = copypartyGroup;
      mode = "0400";
    };

    services.copyparty = {
      enable = true;
      settings = {
        i = "127.0.0.1";
        p = 3923;
      };
      accounts = {
        hieronim.passwordFile = config.sops.secrets.copyparty_hieronim_password.path;
        sarka.passwordFile = config.sops.secrets.copyparty_sarka_password.path;
      };
      groups = {
        family = [
          "hieronim"
          "sarka"
        ];
      };
      volumes = {
        "/" = {
          path = cfg.nasDir;
          access = {
            rw = [ "family" ];
          };
          flags = {
            e2d = true;
            d2t = true;
            scan = 60;
            fk = 4;
          };
        };
      };
      openFilesLimit = 8192;
    };
  };
}
