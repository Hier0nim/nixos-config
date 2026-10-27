{ config, pkgs, ... }:
let
  credentials = config.clan.core.vars.generators.hieronim-copyparty;
  mountRoot = "${config.users.users.hieronim.home}/Network/${config.networking.hostName}";
in
{
  clan.core.vars.generators.hieronim-copyparty = {
    prompts.password = {
      description = "Existing Copyparty password for hieronim";
      type = "hidden";
      persist = true;
    };
    # Deploy only the rclone credential, not the original password.
    files.password.deploy = false;
    files.pass.owner = "hieronim";
    runtimeInputs = [ pkgs.rclone ];
    # rclone obscure is reversible. Store its output as a secret.
    script = ''
      password="$(cat "$out/password")"
      printf '%s' "$password" | rclone obscure - > "$out/pass"
    '';
  };

  # Slow retries to avoid the start limit while DNS reconnects.
  home-manager.users.hieronim.systemd.user.services = {
    "rclone-mount:.nas.hieronim@serverlegion-dav".Service.RestartSec = "5s";
    "rclone-mount:.nas.shared@serverlegion-dav".Service.RestartSec = "5s";
  };

  home-manager.users.hieronim.programs.rclone = {
    enable = true;
    remotes.serverlegion-dav = {
      config = {
        type = "webdav";
        url = "https://pliki.pieczarkowo.me";
        vendor = "owncloud";
        pacer_min_sleep = "0.01ms";
        user = "hieronim";
      };
      secrets.pass = credentials.files.pass.path;
      mounts = {
        "/nas/hieronim" = {
          enable = true;
          mountPoint = "${mountRoot}/hieronim";
          logLevel = "INFO";
          options = {
            vfs-cache-mode = "writes";
            dir-cache-time = "5s";
          };
        };
        "/nas/shared" = {
          enable = true;
          mountPoint = "${mountRoot}/shared";
          logLevel = "INFO";
          options = {
            vfs-cache-mode = "writes";
            dir-cache-time = "5s";
          };
        };
      };
    };
  };
}
