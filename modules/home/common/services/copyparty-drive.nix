{
  config,
  lib,
  pkgs,
  ...
}:
let
  mountPoint = "${config.home.homeDirectory}/Network/${config.custom.hostName}";
  copypartyUrl = "https://pliki.pieczarkowo.me";
  logDir = "${config.xdg.stateHome}/rclone";
  copypartyVolumes = {
    ${config.custom.username} = "/nas/${config.custom.username}";
    shared = "/nas/shared";
  };

  runtimeConfig = pkgs.writeShellScript "copyparty-rclone-config" ''
            set -eu

            runtime_dir="''${XDG_RUNTIME_DIR:?}"
            config_dir="$runtime_dir/rclone"
            config_file="$config_dir/copyparty.conf"
            password_file=${
              lib.escapeShellArg config.sops.secrets."copyparty_${config.custom.username}_password".path
            }
            password="$(${pkgs.coreutils}/bin/tr -d '\n' < "$password_file")"
            obscured_password="$(${pkgs.rclone}/bin/rclone obscure "$password")"

            ${pkgs.coreutils}/bin/mkdir -p "$config_dir"
            ${pkgs.coreutils}/bin/cat > "$config_file" <<EOF
        [serverlegion-dav]
        type = webdav
        url = ${copypartyUrl}
        vendor = owncloud
        pacer_min_sleep = 0.01ms
        user = ${config.custom.username}
        pass = $obscured_password
    EOF
        ${pkgs.coreutils}/bin/chmod 600 "$config_file"
  '';

  mkCopypartyDriveService =
    name: copypartyRoot:
    let
      volumeMountPoint = "${mountPoint}/${name}";
    in
    {
      Unit = {
        Description = "Mount Copyparty ${name} WebDAV as a local drive";
        After = [
          "graphical-session.target"
          "network-online.target"
        ];
        Wants = [
          "graphical-session.target"
          "network-online.target"
        ];
        StartLimitIntervalSec = 0;
      };

      Service = {
        Type = "simple";
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p ${volumeMountPoint}"
          "${pkgs.coreutils}/bin/mkdir -p ${logDir}"
          "${runtimeConfig}"
        ];
        ExecStart = "${pkgs.rclone}/bin/rclone mount --config=%t/rclone/copyparty.conf --vfs-cache-mode=writes --dir-cache-time=5s --cache-dir=%h/.cache/rclone --log-level=INFO --log-file=${logDir}/copyparty-drive-${name}.log serverlegion-dav:${copypartyRoot} ${volumeMountPoint}";
        ExecStop = "/run/wrappers/bin/fusermount3 -u ${volumeMountPoint}";
        Restart = "on-failure";
        RestartSec = 60;
        TimeoutStartSec = 45;
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.util-linux
            ]
          }:/run/wrappers/bin"
        ];
      };

      Install.WantedBy = [ "default.target" ];
    };
in
{
  options.custom.services.copypartyDrive.enable = lib.mkEnableOption "Copyparty WebDAV drive mount";

  config = lib.mkIf config.custom.services.copypartyDrive.enable {
    sops.secrets.${"copyparty_${config.custom.username}_password"} = {
      sopsFile = config.custom.repoPath + "/secrets/common/copyparty.yaml";
      key = "${config.custom.username}_password";
    };

    home.packages = with pkgs; [
      rclone
    ];

    home.activation.ensureCopypartyMountpoint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${mountPoint}"
      mkdir -p "${logDir}"
      mkdir -p "${mountPoint}/${config.custom.username}"
      mkdir -p "${mountPoint}/shared"
    '';

    systemd.user.services = lib.mapAttrs' (
      name: copypartyRoot:
      lib.nameValuePair "copyparty-drive-${name}" (mkCopypartyDriveService name copypartyRoot)
    ) copypartyVolumes;
  };
}
