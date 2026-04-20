{
  config,
  lib,
  pkgs,
  ...
}:
let
  mountPoint = "${config.home.homeDirectory}/Network/server-legion";
  copypartyUrl = "https://pliki.pieczarkowo.me";
  copypartyRoot = "/nas";
  logDir = "${config.xdg.stateHome}/rclone";

  runtimeConfig = pkgs.writeShellScript "copyparty-rclone-config" ''
            set -eu

            runtime_dir="''${XDG_RUNTIME_DIR:?}"
            config_dir="$runtime_dir/rclone"
            config_file="$config_dir/copyparty.conf"
            password_file=${lib.escapeShellArg config.sops.secrets.copyparty_hieronim_password.path}
            password="$(${pkgs.coreutils}/bin/tr -d '\n' < "$password_file")"
            obscured_password="$(${pkgs.rclone}/bin/rclone obscure "$password")"

            ${pkgs.coreutils}/bin/mkdir -p "$config_dir"
            ${pkgs.coreutils}/bin/cat > "$config_file" <<EOF
        [serverlegion-dav]
        type = webdav
        url = ${copypartyUrl}
        vendor = owncloud
        pacer_min_sleep = 0.01ms
        user = hieronim
        pass = $obscured_password
    EOF
        ${pkgs.coreutils}/bin/chmod 600 "$config_file"
  '';

in
{
  sops.secrets.copyparty_hieronim_password = {
    sopsFile = config.custom.repoPath + "/secrets/server-legion/copyparty.yaml";
    key = "hieronim_password";
  };

  home.packages = with pkgs; [
    rclone
  ];

  home.activation.ensureCopypartyMountpoint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${mountPoint}"
    mkdir -p "${logDir}"
  '';

  systemd.user.services.copyparty-drive = {
    Unit = {
      Description = "Mount Copyparty WebDAV as a local drive";
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
        "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}"
        "${pkgs.coreutils}/bin/mkdir -p ${logDir}"
        "${runtimeConfig}"
      ];
      ExecStart = "${pkgs.rclone}/bin/rclone mount --config=%t/rclone/copyparty.conf --vfs-cache-mode=writes --dir-cache-time=5s --cache-dir=%h/.cache/rclone --log-level=INFO --log-file=${logDir}/copyparty-drive.log serverlegion-dav:${copypartyRoot} ${mountPoint}";
      ExecStop = "/run/wrappers/bin/fusermount3 -u ${mountPoint}";
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
}
