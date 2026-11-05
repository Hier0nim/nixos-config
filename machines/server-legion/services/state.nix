{
  config,
  lib,
  pkgs,
  ...
}:
let
  snapshotRoot = "/var/backup/homelab";
  identityEnabled = config.services.authelia.instances.homelab.enable or false;
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
      name = "copyparty-state";
      unit = "copyparty.service";
      source = "/var/lib/copyparty";
    }
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
  ]
  ++ lib.optional identityEnabled {
    name = "authelia";
    unit = "authelia-homelab.service";
    source = "/var/lib/authelia-homelab";
    exclude = [ "notifications.txt" ];
  }
  ++ lib.optional config.services.ntfy-sh.enable {
    name = "ntfy";
    unit = "ntfy-sh.service";
    source = "/var/lib/private/ntfy-sh";
  }
  ++ lib.optional config.services.gatus.enable {
    name = "gatus";
    unit = "gatus.service";
    source = "/var/lib/private/gatus";
  }
  ++ lib.optional config.services.mealie.enable {
    name = "mealie";
    unit = "mealie.service";
    source = "/var/lib/private/mealie";
  }
  ++ lib.optional config.services.donetick.enable {
    name = "donetick";
    unit = "docker-donetick.service";
    source = "/var/lib/donetick";
  }
  ++ lib.optional config.services.paperless.enable {
    name = "paperless";
    unit = "paperless-state.target";
    source = config.services.paperless.dataDir;
    # Keep large document snapshots on SATA so reflinks work and NVMe is not filled.
    snapshot = "/data/.homelab-backup/paperless";
  };
  snapshotPath = service: service.snapshot or "${snapshotRoot}/${service.name}";
  snapshotWrites = [
    snapshotRoot
  ]
  ++ lib.optional config.services.paperless.enable "/data/.homelab-backup";
  snapshotSources = map (service: service.source) snapshotServices;
  snapshotScript = lib.concatMapStringsSep "\n" (service: ''
    if ${systemctl} is-active --quiet ${lib.escapeShellArg service.unit}; then
      active_units+=( ${lib.escapeShellArg service.unit} )
      ${systemctl} stop ${lib.escapeShellArg service.unit}
    fi
  '') snapshotServices;
  snapshotCopies = lib.concatMapStringsSep "\n" (service: ''
    copy_snapshot ${lib.escapeShellArg service.source} ${lib.escapeShellArg (snapshotPath service)} ${
      lib.concatMapStringsSep " " lib.escapeShellArg (service.exclude or [ ])
    }
  '') snapshotServices;
  snapshotCleanup = lib.concatMapStringsSep "\n" (
    service:
    let
      destination = snapshotPath service;
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
      snapshot=${lib.escapeShellArg (snapshotPath service)}
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
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail
      umask 077
      if [ "$#" -ne 1 ]; then
        echo "Usage: homelab-restore-state ${
          lib.concatStringsSep "|" (map (service: service.name) snapshotServices)
        }|forgejo" >&2
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
      # Serialize restores with snapshots before stopping any service.
      exec 9>${lib.escapeShellArg "${snapshotRoot}/.state.lock"}
      flock -n 9 || { echo "Another state snapshot or restore is running" >&2; exit 1; }
      rollback=$(mktemp -d "''${source}.before-borg-restore-XXXXXXXX")
      was_active=false
      stop_attempted=false
      saved=false
      copying=false
      complete=false
      if ${systemctl} is-active --quiet "$unit"; then
        was_active=true
      fi
      # On failure, restore old data only after confirming the service has stopped.
      cleanup() {
        status=$?
        trap - EXIT INT TERM
        if ! "$complete"; then
          if "$copying"; then
            if ! ${systemctl} stop "$unit"; then
              echo "Cannot stop $unit for rollback. Previous state retained at $rollback" >&2
              exit 1
            fi
            rm -rf -- "$source" || exit 1
          fi
          if "$saved"; then
            if ! mv -T -- "$rollback" "$source"; then
              echo "Cannot restore previous state from $rollback; $unit remains stopped" >&2
              exit 1
            fi
          else
            rmdir -- "$rollback" || true
          fi
          if "$was_active" && "$stop_attempted"; then
            ${systemctl} start "$unit" || status=1
          fi
        fi
        exit "$status"
      }
      trap cleanup EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM
      stop_attempted=true
      ${systemctl} stop "$unit"
      if [ -e "$source" ] || [ -L "$source" ]; then
        mv -T -- "$source" "$rollback"
        saved=true
      fi
      copying=true
      cp -a --reflink=auto "$snapshot" "$source"
      if "$was_active"; then
        ${systemctl} start "$unit"
      fi
      complete=true
      if "$saved"; then
        echo "Restored $1. Previous state retained at $rollback"
      else
        rmdir -- "$rollback"
        echo "Restored $1. No previous state existed."
      fi
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

    ntfy.folders = lib.mkIf config.services.ntfy-sh.enable [ "${snapshotRoot}/ntfy" ];
    gatus.folders = lib.mkIf config.services.gatus.enable [ "${snapshotRoot}/gatus" ];
    mealie.folders = lib.mkIf config.services.mealie.enable [ "${snapshotRoot}/mealie" ];
    donetick.folders = lib.mkIf config.services.donetick.enable [ "${snapshotRoot}/donetick" ];
    paperless.folders = lib.mkIf config.services.paperless.enable [ "/data/.homelab-backup/paperless" ];

    copyparty.folders = [ "/data/nas" ];
    copyparty-state.folders = [ "${snapshotRoot}/copyparty-state" ];

    authelia = lib.mkIf identityEnabled {
      folders = [ "${snapshotRoot}/authelia" ];
    };
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
        "/data/photos/upload"
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
    tmpfiles.rules = map (path: "d ${path} 0700 root root - -") snapshotWrites;

    services.homelab-app-state-snapshot = {
      description = "Create consistent snapshots of stateful homelab apps";
      unitConfig.RequiresMountsFor = snapshotSources ++ snapshotWrites;
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
        ReadWritePaths = snapshotWrites;
        TimeoutStartSec = "infinity";
      };
      path = [
        pkgs.coreutils
        pkgs.util-linux
      ];
      script = ''
        set -euo pipefail
        exec 9>${lib.escapeShellArg "${snapshotRoot}/.state.lock"}
        flock -n 9 || { echo "Another state snapshot or restore is running" >&2; exit 1; }
        active_units=()
        cleanup() {
          status=$?
          trap - EXIT INT TERM
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
        trap 'exit 130' INT
        trap 'exit 143' TERM
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
      "/data/photos/upload"
    ];
  };
}
