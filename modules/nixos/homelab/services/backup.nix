{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  backupCfg = cfg.backup;
  inherit (config.networking) hostName;
  inherit (config.custom) repoPath;

  secretsFile = "${repoPath}/secrets/${hostName}/backup.yaml";

  inherit (backupCfg) mountPoint;
  repositoryPathDefault = "${mountPoint}/restic/${hostName}";
  repositoryPath =
    if backupCfg.repositoryPath != null then backupCfg.repositoryPath else repositoryPathDefault;
  inherit (backupCfg) schedule checkSchedule;
  serviceBackups = lib.filterAttrs (_: svc: svc.backup.enable) cfg.services;
  serviceBackupPaths = lib.concatLists (
    map (name: cfg.services.${name}.backup.paths) (builtins.attrNames serviceBackups)
  );
  serviceBackupExcludes = lib.concatLists (
    map (name: cfg.services.${name}.backup.exclude) (builtins.attrNames serviceBackups)
  );
  backupPaths = lib.unique serviceBackupPaths;
  backupExcludes = lib.unique serviceBackupExcludes;

  inherit (pkgs) restic coreutils util-linux;
  resticBin = "${restic}/bin/restic";
  mountpointBin = "${util-linux}/bin/mountpoint";
  statBin = "${coreutils}/bin/stat";
  installBin = "${coreutils}/bin/install";

  resticGlobalArgs = lib.concatStringsSep " " [
    "--repo ${lib.escapeShellArg repositoryPath}"
    "--password-file ${lib.escapeShellArg config.sops.secrets.restic_backup_password.path}"
  ];

  resticBase = "${resticBin} ${resticGlobalArgs}";
  compressionArgs = [
    "--compression"
    "auto"
  ];
  tagArgs = [
    "--tag"
    "host:${hostName}"
    "--tag"
    "target:router-smb"
    "--tag"
    "scope:homelab"
  ];

  preflightScript = pkgs.writeShellScript "homelab-restic-preflight" ''
    set -euo pipefail
    mount_point=${lib.escapeShellArg mountPoint}
    repo=${lib.escapeShellArg repositoryPath}

    ${coreutils}/bin/ls "$mount_point" >/dev/null 2>&1 || true

    if ! ${mountpointBin} -q "$mount_point"; then
      echo "restic backup aborted: $mount_point is not mounted" >&2
      exit 1
    fi

    if [ ! -d "$repo" ]; then
      echo "restic backup aborted: repository path missing: $repo" >&2
      exit 1
    fi

    mount_dev="$(${statBin} -c %d "$mount_point")"
    repo_dev="$(${statBin} -c %d "$repo")"
    if [ "$mount_dev" != "$repo_dev" ]; then
      echo "restic backup aborted: repository is not on the backup mount: $repo" >&2
      exit 1
    fi
  '';

  initPreflightScript = pkgs.writeShellScript "homelab-restic-init-preflight" ''
    set -euo pipefail
    mount_point=${lib.escapeShellArg mountPoint}
    repo=${lib.escapeShellArg repositoryPath}
    repo_parent="$(dirname "$repo")"

    ${coreutils}/bin/ls "$mount_point" >/dev/null 2>&1 || true

    if ! ${mountpointBin} -q "$mount_point"; then
      echo "restic init aborted: $mount_point is not mounted" >&2
      exit 1
    fi

    ${installBin} -d -m 0700 "$repo_parent"

    mount_dev="$(${statBin} -c %d "$mount_point")"
    parent_dev="$(${statBin} -c %d "$repo_parent")"
    if [ "$mount_dev" != "$parent_dev" ]; then
      echo "restic init aborted: repository parent is not on the backup mount: $repo_parent" >&2
      exit 1
    fi

    if [ -e "$repo" ]; then
      echo "restic init aborted: repository already exists at $repo" >&2
      exit 1
    fi
  '';

  initScript = pkgs.writeShellScript "homelab-restic-init" ''
    set -euo pipefail
    ${resticBase} init --repository-version 2
  '';

  backupPrepareCommand = ''
    ${preflightScript}
  '';
in
{
  config = lib.mkIf (cfg.enable && backupCfg.enable) {
    homelab.backup = {
      repositoryPath = lib.mkDefault repositoryPathDefault;
    };

    assertions = [
      {
        assertion =
          let
            mountPrefix = "${backupCfg.mountPoint}/";
          in
          lib.hasPrefix mountPrefix repositoryPath;
        message = "homelab.backup.repositoryPath must live under homelab.backup.mountPoint.";
      }
      {
        assertion =
          let
            forbidden = [
              "${cfg.data.photos}/upload"
              "${cfg.data.photos}/thumbs"
              "${cfg.data.photos}/encoded-video"
              "${cfg.state.root}"
            ];
          in
          lib.intersectLists forbidden backupPaths == [ ];
        message = "Do not back up /data/photos/{upload,thumbs,encoded-video} or the entire /var/lib/homelab root.";
      }
    ];

    sops.secrets = {
      router_backup_username = {
        sopsFile = secretsFile;
        key = "router_backup_username";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      router_backup_password = {
        sopsFile = secretsFile;
        key = "router_backup_password";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      restic_backup_password = {
        sopsFile = secretsFile;
        key = "restic_backup_password";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    sops.templates."backup-router-credentials" = {
      path = "/run/backup-router-credentials";
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        username=${config.sops.placeholder.router_backup_username}
        password=${config.sops.placeholder.router_backup_password}
      '';
    };

    fileSystems."${mountPoint}" = {
      device = "//192.168.8.1/backup";
      fsType = "cifs";
      options = [
        "credentials=${config.sops.templates."backup-router-credentials".path}"
        "vers=3.1.1"
        "uid=0"
        "gid=0"
        "file_mode=0600"
        "dir_mode=0700"
        "nofail"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=10min"
        "x-systemd.device-timeout=10s"
        "x-systemd.mount-timeout=30s"
        "x-systemd.requires=network-online.target"
        "x-systemd.after=network-online.target"
      ];
    };

    systemd = {
      tmpfiles.rules = [
        "d ${mountPoint} 0700 root root - -"
      ];
      services = {
        "restic-backups-homelab" = {
          unitConfig.RequiresMountsFor = [ mountPoint ];
          serviceConfig = {
            Nice = 10;
            IOSchedulingClass = "best-effort";
            IOSchedulingPriority = 7;
          };
        };
        "restic-backups-homelab-check" = {
          unitConfig.RequiresMountsFor = [ mountPoint ];
          serviceConfig = {
            Nice = 10;
            IOSchedulingClass = "best-effort";
            IOSchedulingPriority = 7;
          };
        };
        homelab-backup-restic-init = {
          description = "Homelab restic repository initialization";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          unitConfig.RequiresMountsFor = [ mountPoint ];
          serviceConfig = {
            Type = "oneshot";
            ExecStartPre = [ initPreflightScript ];
            ExecStart = initScript;
            User = "root";
            Group = "root";
          };
        };
      };
    };

    environment.systemPackages = [
      pkgs.cifs-utils
    ];

    services.restic.backups.homelab = {
      repository = repositoryPath;
      passwordFile = config.sops.secrets.restic_backup_password.path;
      inhibitsSleep = true;
      paths = backupPaths;
      exclude = backupExcludes;
      extraBackupArgs = compressionArgs ++ tagArgs;
      progressFps = 0;
      pruneOpts = [
        "--keep-daily 5"
        "--keep-weekly 3"
        "--keep-monthly 2"
      ];
      checkOpts = [ ];
      initialize = false;
      timerConfig = {
        OnCalendar = schedule;
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
      inherit backupPrepareCommand;
    };

    services.restic.backups.homelab-check = {
      repository = repositoryPath;
      passwordFile = config.sops.secrets.restic_backup_password.path;
      inhibitsSleep = true;
      paths = [ ];
      pruneOpts = [ ];
      runCheck = true;
      checkOpts = [ "--read-data-subset=10%" ];
      progressFps = 0;
      initialize = false;
      timerConfig = {
        OnCalendar = checkSchedule;
        Persistent = true;
      };
      inherit backupPrepareCommand;
    };

    # Restore workflow (examples):
    # - List snapshots:  restic-homelab snapshots
    # - Restore file:    restic-homelab restore <snapshot> --target /restore --include /path/to/file
    # - Restore dir:     restic-homelab restore <snapshot> --target /restore --include /path/to/dir
    # - Browse repo:     restic-homelab mount /mnt/restic-mount
  };
}
