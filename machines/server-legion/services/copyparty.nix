{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  varFiles = config.clan.core.vars.generators.copyparty.files;
  passwords = {
    admin = varFiles.admin-password.path;
    hieronim = varFiles.hieronim-password.path;
    sarka = varFiles.sarka-password.path;
  };
  volumeFlags = {
    e2d = true;
    d2t = true;
    scan = 60;
    fk = 4;
  };
in
{
  imports = [ self.inputs.copyparty.nixosModules.default ];

  clan.core.vars.generators.copyparty = {
    files = {
      admin-password = {
        owner = "copyparty";
        group = "copyparty";
        mode = "0400";
      };
      hieronim-password = {
        owner = "copyparty";
        group = "copyparty";
        mode = "0400";
      };
      sarka-password = {
        owner = "copyparty";
        group = "copyparty";
        mode = "0400";
      };
    };
    prompts = {
      admin-password = {
        description = "Copyparty administrator password";
        type = "hidden";
      };
      hieronim-password = {
        description = "Copyparty Hieronim account password";
        type = "hidden";
      };
      sarka-password = {
        description = "Copyparty Sarka account password";
        type = "hidden";
      };
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      install -m 0400 "$prompts/admin-password" "$out/admin-password"
      install -m 0400 "$prompts/hieronim-password" "$out/hieronim-password"
      install -m 0400 "$prompts/sarka-password" "$out/sarka-password"
    '';
  };

  users.users.copyparty.extraGroups = [ "nas" ];

  services.copyparty = {
    enable = true;
    user = "copyparty";
    group = "copyparty";
    openFilesLimit = 8192;

    settings = {
      i = "127.0.0.1";
      p = 3923;
      rproxy = 1;
    };

    accounts = {
      admin.passwordFile = passwords.admin;
      hieronim.passwordFile = passwords.hieronim;
      sarka.passwordFile = passwords.sarka;
    };

    groups.shared = [
      "hieronim"
      "sarka"
    ];

    volumes = {
      "/nas/shared" = {
        path = "/data/nas/shared";
        access.rwmd = [
          "admin"
          "hieronim"
          "sarka"
        ];
        flags = volumeFlags;
      };
      "/nas/hieronim" = {
        path = "/data/nas/hieronim";
        access.rwmd = [
          "admin"
          "hieronim"
        ];
        flags = volumeFlags;
      };
      "/nas/sarka" = {
        path = "/data/nas/sarka";
        access.rwmd = [
          "admin"
          "sarka"
        ];
        flags = volumeFlags;
      };
    };
  };

  systemd.services.copyparty.serviceConfig = {
    SupplementaryGroups = [ "nas" ];
    UMask = lib.mkForce "0022";
  };
}
