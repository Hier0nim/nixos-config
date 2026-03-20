{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  inherit (config.networking) hostName;

  copypartyUser = cfg.services.copyparty.user;
  copypartyGroup = cfg.services.copyparty.group;
  copypartySecretsFile = "${config.custom.repoPath}/secrets/${hostName}/copyparty.yaml";

  mkCopypartyPasswordSecret = key: {
    sopsFile = copypartySecretsFile;
    inherit key;
    owner = copypartyUser;
    group = copypartyGroup;
    mode = "0400";
  };

  commonVolumeFlags = {
    e2d = true;
    d2t = true;
    scan = 60;
    fk = 4;
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.files.enable && cfg.services.copyparty.enable) {
    homelab.services.copyparty.expose.reverseProxyExtraConfig = lib.mkDefault ''
      header_up X-Real-IP {remote_host}
    '';

    sops.secrets = {
      copyparty_admin_password = mkCopypartyPasswordSecret "admin_password";
      copyparty_hieronim_password = mkCopypartyPasswordSecret "hieronim_password";
      copyparty_sarka_password = mkCopypartyPasswordSecret "sarka_password";
    };

    services.copyparty = {
      enable = true;
      user = copypartyUser;
      group = copypartyGroup;

      settings = {
        i = "127.0.0.1";
        p = cfg.services.copyparty.upstream.port;
        rproxy = 1;
      };

      accounts = {
        admin.passwordFile = config.sops.secrets.copyparty_admin_password.path;
        hieronim.passwordFile = config.sops.secrets.copyparty_hieronim_password.path;
        sarka.passwordFile = config.sops.secrets.copyparty_sarka_password.path;
      };

      groups = {
        shared = [
          "hieronim"
          "sarka"
        ];
      };

      volumes = {
        "/nas/shared" = {
          path = "${cfg.data.nas}/shared";
          access = {
            rwd = [
              "admin"
              "hieronim"
              "sarka"
            ];
          };
          flags = commonVolumeFlags;
        };
        "/nas/hieronim" = {
          path = "${cfg.data.nas}/hieronim";
          access = {
            rwd = [
              "admin"
              "hieronim"
            ];
          };
          flags = commonVolumeFlags;
        };
        "/nas/sarka" = {
          path = "${cfg.data.nas}/sarka";
          access = {
            rwd = [
              "admin"
              "sarka"
            ];
          };
          flags = commonVolumeFlags;
        };
      };

      openFilesLimit = 8192;
    };
  };
}
