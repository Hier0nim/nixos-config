{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  backupCfg = cfg.backups;
  inherit (config.networking) hostName;
  inherit (config.custom) repoPath;

  resticSecretsFile = "${repoPath}/secrets/${hostName}/backup.yaml";
  rcloneSecretsFile = "${repoPath}/secrets/${hostName}/rclone/proton.conf";
  resticCacheDir = "/var/cache/restic-backups-homelab-proton";
in
{
  config = lib.mkIf (cfg.enable && backupCfg.enable) {
    # Proton Drive via rclone is best-effort; keep this host as the only writer.
    # Do not mount Proton Drive or use rclone sync here—restic remains the source of truth.
    # Avoid assuming modtime support from Proton Drive; rely on restic metadata instead.
    # Restore examples:
    #   restic-homelab-backup-snapshots
    #   restic-homelab-proton restore latest --target /var/tmp/restic-restore
    #   restic-homelab-proton restore latest --target /var/tmp/restic-restore --include /data/photos/library

    sops = {
      secrets.${backupCfg.passwordSecretName} = {
        sopsFile = resticSecretsFile;
        key = backupCfg.passwordSecretName;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      secrets.${backupCfg.rcloneConfigSecretName} = {
        sopsFile = rcloneSecretsFile;
        format = "binary";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    services.restic.backups.homelab-proton = {
      initialize = true;
      inherit (backupCfg) paths timerConfig;
      user = "root";
      passwordFile = config.sops.secrets.${backupCfg.passwordSecretName}.path;
      repository = "rclone:${backupCfg.repositoryRemoteName}:${backupCfg.repositoryPath}";
      rcloneConfigFile = config.sops.secrets.${backupCfg.rcloneConfigSecretName}.path;
      rcloneOptions = {
        retries = "10";
        low-level-retries = "20";
        retries-sleep = "10s";
      };
      rcloneConfig = {
        replace_existing_draft = true;
      };
      extraBackupArgs = [
        "--compression"
        "max"
        "--one-file-system"
      ];
      backupPrepareCommand =
        #bash
        ''
          if restic cat config >/dev/null 2>&1; then
            if ! restic cat config | grep -Eq '"version"[[:space:]]*:[[:space:]]*2'; then
              echo "restic repository is not v2; migrate or re-init with --repository-version 2" >&2
              exit 1
            fi
          else
            restic init --repository-version 2
          fi
        '';
      pruneOpts = [
        "--keep-daily ${toString backupCfg.retention.daily}"
        "--keep-weekly ${toString backupCfg.retention.weekly}"
        "--keep-monthly ${toString backupCfg.retention.monthly}"
      ];
    };

    systemd = {
      services.restic-backups-homelab-proton.path = lib.mkAfter [
        pkgs.rclone
        pkgs.restic
      ];

      services.restic-check-homelab-proton = lib.mkIf backupCfg.check.enable {
        description = "Restic integrity check (homelab proton)";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [
          pkgs.rclone
          pkgs.restic
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Environment = [
            "RCLONE_CONFIG=${config.sops.secrets.${backupCfg.rcloneConfigSecretName}.path}"
            "RESTIC_PASSWORD_FILE=${config.sops.secrets.${backupCfg.passwordSecretName}.path}"
            "RESTIC_REPOSITORY=rclone:${backupCfg.repositoryRemoteName}:${backupCfg.repositoryPath}"
            "RESTIC_CACHE_DIR=${resticCacheDir}"
          ];
          CacheDirectory = "restic-backups-homelab-proton";
          CacheDirectoryMode = "0700";
          PrivateTmp = true;
        };
        script = ''
          exec ${pkgs.restic}/bin/restic check --read-data-subset=5%
        '';
      };

      timers.restic-check-homelab-proton = lib.mkIf backupCfg.check.enable {
        wantedBy = [ "timers.target" ];
        inherit (backupCfg.check) timerConfig;
      };
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "restic-homelab-backup-run" ''
        exec ${pkgs.systemd}/bin/systemctl start restic-backups-homelab-proton.service
      '')
      (pkgs.writeShellScriptBin "restic-homelab-backup-check" ''
        exec ${pkgs.systemd}/bin/systemctl start restic-check-homelab-proton.service
      '')
      (pkgs.writeShellScriptBin "restic-homelab-backup-snapshots" ''
        exec restic-homelab-proton snapshots "$@"
      '')
    ];
  };
}
