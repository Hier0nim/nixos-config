{
  config,
  lib,
  pkgs,
  ...
}:
let
  snapshotRoot = "/var/backup/homelab";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  nixflixStateDir = config.nixflix.stateDir;
  arrBackupDirs = map (name: "${nixflixStateDir}/${name}/Backups") [
    "sonarr"
    "sonarr-anime"
    "radarr"
    "prowlarr"
  ];
  snapshotServices = [
    {
      name = "actual";
      unit = "actual.service";
      source = "/var/lib/private/actual";
    }
    {
      name = "enable-actual";
      unit = "docker-enable-actual.service";
      source = "/var/lib/homelab/enable-actual";
    }
    {
      name = "audiobookshelf";
      unit = "audiobookshelf.service";
      source = "/var/lib/audiobookshelf";
      exclude = [
        "metadata/backups"
        "metadata/logs"
      ];
    }
    {
      name = "listenarr";
      unit = "docker-listenarr.service";
      source = "/var/lib/listenarr";
    }
    {
      name = "jellyfin";
      unit = "jellyfin.service";
      source = "${nixflixStateDir}/jellyfin";
      exclude = [ "log" ];
    }
    {
      name = "seerr";
      unit = "seerr.service";
      source = "${nixflixStateDir}/seerr";
      exclude = [
        "cache"
        "logs"
      ];
    }
  ];
  snapshotSources = map (service: service.source) snapshotServices;
  snapshotScript = lib.concatMapStringsSep "\n" (service: ''
    if ${systemctl} is-active --quiet ${lib.escapeShellArg service.unit}; then
      active_units+=( ${lib.escapeShellArg service.unit} )
      ${systemctl} stop ${lib.escapeShellArg service.unit}
    fi
  '') snapshotServices;
  snapshotCopies = lib.concatMapStringsSep "\n" (service: ''
    copy_snapshot ${lib.escapeShellArg service.source} ${lib.escapeShellArg "${snapshotRoot}/${service.name}"} ${
      lib.concatMapStringsSep " " lib.escapeShellArg (service.exclude or [ ])
    }
  '') snapshotServices;
  snapshotCleanup = lib.concatMapStringsSep "\n" (
    service:
    let
      destination = "${snapshotRoot}/${service.name}";
    in
    ''
      rm -rf ${lib.escapeShellArg "${destination}.new"} || status=1
      if [ ! -e ${lib.escapeShellArg destination} ] && [ -e ${lib.escapeShellArg "${destination}.old"} ]; then
        mv -T ${lib.escapeShellArg "${destination}.old"} ${lib.escapeShellArg destination} || status=1
      fi
    ''
  ) snapshotServices;
  restoreCases = lib.concatMapStringsSep "\n" (service: ''
    ${service.name})
      unit=${lib.escapeShellArg service.unit}
      source=${lib.escapeShellArg service.source}
      snapshot=${lib.escapeShellArg "${snapshotRoot}/${service.name}"}
      ;;
  '') snapshotServices;
  arrFreshnessCheck = lib.concatMapStringsSep "\n" (dir: ''
    if ! ${pkgs.findutils}/bin/find ${lib.escapeShellArg dir} -type f -mmin -1560 -print -quit | ${pkgs.gnugrep}/bin/grep -q .; then
      echo "No Arr backup newer than 26 hours in ${dir}" >&2
      exit 1
    fi
  '') arrBackupDirs;
  restoreCommand = pkgs.writeShellApplication {
    name = "homelab-restore-state";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail
      if [ "$#" -ne 1 ]; then
        echo "Usage: homelab-restore-state actual|enable-actual|audiobookshelf|listenarr|forgejo|jellyfin|seerr" >&2
        exit 2
      fi
      case "$1" in
        ${restoreCases}
        forgejo)
          unit="forgejo.service"
          source=${lib.escapeShellArg config.services.forgejo.stateDir}
          snapshot="/var/lib/homelab/forgejo-backup"
          ;;
        *)
          echo "Unknown state: $1" >&2
          exit 2
          ;;
      esac
      if [ ! -d "$snapshot" ]; then
        echo "Snapshot not found: $snapshot" >&2
        exit 1
      fi
      ${systemctl} stop "$unit"
      rollback="''${source}.before-borg-restore-$(date +%Y%m%d%H%M%S)"
      if [ -e "$source" ]; then
        mv -T "$source" "$rollback"
      fi
      if ! cp -a --reflink=auto "$snapshot" "$source"; then
        rm -rf "$source"
        if [ -e "$rollback" ]; then
          mv -T "$rollback" "$source"
        fi
        ${systemctl} start "$unit" || true
        exit 1
      fi
      if ! ${systemctl} start "$unit"; then
        echo "Restore copied, but $unit did not start. Previous state is at $rollback" >&2
        exit 1
      fi
      echo "Restored $1. Previous state retained at $rollback"
    '';
  };
in
{
  clan.core.state = {
    app-state-snapshots = {
      folders = [ ];
      preBackupScript = "${systemctl} start homelab-app-state-snapshot.service";
    };

    arr-backups = {
      folders = arrBackupDirs;
      preBackupScript = ''
        ${arrFreshnessCheck}
      '';
    };

    copyparty.folders = [ "/data/nas" ];

    actual.folders = [ "${snapshotRoot}/actual" ];
    enable-actual.folders = [ "${snapshotRoot}/enable-actual" ];
    audiobookshelf.folders = [ "${snapshotRoot}/audiobookshelf" ];
    listenarr.folders = [ "${snapshotRoot}/listenarr" ];
    forgejo-snapshot = {
      folders = [ "/var/lib/homelab/forgejo-backup" ];
      preBackupScript = "${systemctl} start forgejo-snapshot.service";
    };
    jellyfin.folders = [ "${snapshotRoot}/jellyfin" ];
    seerr.folders = [ "${snapshotRoot}/seerr" ];

    immich-media = {
      folders = [
        "/data/photos/library"
        "/data/photos/backups"
        "/data/photos/profile"
        "/var/lib/homelab/immich-hot/upload"
      ];
      preBackupScript = ''
        if ! ${pkgs.findutils}/bin/find /data/photos/backups -type f -name '*.sql.gz' -mmin -1560 -print -quit | ${pkgs.gnugrep}/bin/grep -q .; then
          echo "No Immich database dump newer than 26 hours in /data/photos/backups" >&2
          exit 1
        fi
      '';
    };
  };

  systemd = {
    tmpfiles.rules = [ "d ${snapshotRoot} 0700 root root - -" ];

    services.homelab-app-state-snapshot = {
      description = "Create consistent snapshots of stateful homelab apps";
      unitConfig.RequiresMountsFor = snapshotSources ++ [ snapshotRoot ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = snapshotSources;
        ReadWritePaths = [ snapshotRoot ];
        TimeoutStartSec = "infinity";
      };
      path = [ pkgs.coreutils ];
      script = ''
        set -euo pipefail
        active_units=()
        cleanup() {
          status=$?
          trap - EXIT
          ${snapshotCleanup}
          for unit in "''${active_units[@]}"; do
            ${systemctl} start "$unit" || status=1
          done
          exit "$status"
        }
        copy_snapshot() {
          source="$1"
          destination="$2"
          temporary="''${destination}.new"
          previous="''${destination}.old"
          shift 2
          if [ ! -d "$source" ]; then
            echo "Application state directory is missing: $source" >&2
            return 1
          fi
          rm -rf "$temporary"
          mkdir -m 0700 "$temporary"
          cp -a --reflink=auto "$source/." "$temporary/"
          for relative_path in "$@"; do
            rm -rf "$temporary/$relative_path"
          done
          rm -rf "$previous"
          if [ -e "$destination" ]; then
            mv -T "$destination" "$previous"
          fi
          if ! mv -T "$temporary" "$destination"; then
            if [ -e "$previous" ]; then
              mv -T "$previous" "$destination"
            fi
            return 1
          fi
          rm -rf "$previous"
        }
        trap cleanup EXIT
        ${snapshotScript}
        ${snapshotCopies}
      '';
    };
  };

  environment.systemPackages = [ restoreCommand ];

  systemd.services.borgbackup-job-hetzner-storagebox = {
    environment.BORG_REMOTE_PATH = "borg-1.4";
    unitConfig.RequiresMountsFor = [
      "/data/nas"
      "/data/photos/library"
      "/data/photos/backups"
      "/data/photos/profile"
    ];
  };
}
