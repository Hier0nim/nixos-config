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
  config = lib.mkIf (cfg.enable && cfg.files.enable) {
    users.users.${copypartyUser}.extraGroups = [
      "media"
    ];

    sops.secrets = {
      copyparty_admin_password = mkCopypartyPasswordSecret "admin_password";
      copyparty_hieronim_password = mkCopypartyPasswordSecret "hieronim_password";
      copyparty_sarka_password = mkCopypartyPasswordSecret "sarka_password";
    };

    systemd.tmpfiles.rules = [
      # NAS is writable by Copyparty.
      "d ${cfg.nasDir} 0770 root ${copypartyGroup} - -"
      "Z ${cfg.nasDir} 0770 root ${copypartyGroup} - -"

      # Photos are only read by Copyparty; ownership is handled by Immich.
      "d ${cfg.photosDir} 0750 root media - -"
    ];

    services.copyparty = {
      enable = true;

      settings = {
        i = "127.0.0.1";
        p = 3923;
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
        "/nas" = {
          path = cfg.nasDir;
          access = {
            rw = [
              "admin"
              "hieronim"
              "sarka"
            ];
          };
          flags = commonVolumeFlags;
        };
      }
      // lib.optionalAttrs cfg.photos.enable {
        "/photos" = {
          path = cfg.photosDir;
          access = {
            r = [
              "admin"
              "hieronim"
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
