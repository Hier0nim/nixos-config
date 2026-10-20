# NixOS module: Copyparty credentials and their Home Manager rclone mounts.
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
    # Retain the canonical password for future server integration without
    # deploying it to this client. Only rclone's derived file is needed here.
    files.password.deploy = false;
    files.pass.owner = "hieronim";
    runtimeInputs = [ pkgs.rclone ];
    # Obscuring is rclone's file format, not encryption. Clan keeps it secret.
    script = ''
      password="$(cat "$out/password")"
      printf '%s' "$password" | rclone obscure - > "$out/pass"
    '';
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
