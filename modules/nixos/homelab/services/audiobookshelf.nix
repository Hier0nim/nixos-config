{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  audiobookshelfService = cfg.services.audiobookshelf;
  libraryDir = "${cfg.data.media}/audiobooks";
  reviewDir = "${cfg.data.downloads}/review/audiobooks";
  importStateDir = "/var/lib/homelab/audiobook-import";

  torrentDir = "${cfg.data.downloads}/torrent/audiobooks";

  audiobookReview = pkgs.writeShellApplication {
    name = "audiobook-review";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      set -euo pipefail

      dry_run=0

      usage() {
        cat <<'EOF'
      Usage: audiobook-review [--dry-run] SOURCE [DESTINATION]

      Copy one completed audiobook download from qBittorrent's audiobook category
      into the human review staging directory, leaving the torrent copy untouched
      for seeding.

      SOURCE must be a directory under:
        ${torrentDir}

      DESTINATION is optional and relative to:
        ${reviewDir}

      Examples:
        audiobook-review --dry-run "/data/downloads/torrent/audiobooks/Release Name"
        sudo audiobook-review "/data/downloads/torrent/audiobooks/Release Name" "Terry Pratchett - Guards! Guards!"
      EOF
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --dry-run) dry_run=1; shift ;;
          -h|--help) usage; exit 0 ;;
          --) shift; break ;;
          -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
          *) break ;;
        esac
      done

      if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        usage >&2
        exit 2
      fi

      torrent_root=${lib.escapeShellArg torrentDir}
      review_root=${lib.escapeShellArg reviewDir}
      log_dir=${lib.escapeShellArg importStateDir}

      source_real=$(realpath -- "$1")
      if [ ! -d "$source_real" ]; then
        echo "Source is not a directory: $1" >&2
        exit 1
      fi

      if [ -L "$source_real" ]; then
        echo "Refusing to copy symlink source: $source_real" >&2
        exit 1
      fi

      case "$source_real" in
        "$torrent_root"/*) ;;
        *)
          echo "Source must be under $torrent_root" >&2
          exit 1
          ;;
      esac

      symlink=$(find "$source_real" -type l -print -quit)
      if [ -n "$symlink" ]; then
        echo "Refusing to copy tree containing symlink: $symlink" >&2
        exit 1
      fi

      source_name=$(basename -- "$source_real")
      dest_rel=''${2:-$source_name}

      case "$dest_rel" in
        ""|/*|..|../*|*/..|*/../*)
          echo "Destination must be a safe relative path, got: $dest_rel" >&2
          exit 1
          ;;
      esac

      dest="$review_root/$dest_rel"
      if [ -e "$dest" ]; then
        echo "Review destination already exists: $dest" >&2
        exit 1
      fi

      echo "Review source:      $source_real"
      echo "Review destination: $dest"
      echo "Torrent source will be left untouched for seeding."

      if [ "$dry_run" -eq 1 ]; then
        echo "Dry run only; no files changed."
        exit 0
      fi

      mkdir -p -- "$(dirname -- "$dest")" "$log_dir"
      cp -a --reflink=auto -- "$source_real" "$dest"
      chgrp -R media "$dest"
      find "$dest" -type d -exec chmod 2775 {} +
      find "$dest" -type f -exec chmod 0664 {} +

      printf '%s\t%s\t%s\n' "$(date --iso-8601=seconds)" "$source_real" "$dest" >> "$log_dir/reviews.log"
      echo "Copied for review. Keep the original qBittorrent torrent active until tracker obligations are satisfied."
    '';
  };

  audiobookImport = pkgs.writeShellApplication {
    name = "audiobook-import";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      set -euo pipefail

      dry_run=0

      usage() {
        cat <<'EOF'
      Usage: audiobook-import [--dry-run] SOURCE [DESTINATION]

      Move one reviewed audiobook directory into the Audiobookshelf library.

      SOURCE must be a directory under:
        ${reviewDir}

      DESTINATION is optional and relative to:
        ${libraryDir}

      Examples:
        audiobook-import --dry-run "/data/downloads/review/audiobooks/Author - Title"
        sudo audiobook-import "/data/downloads/review/audiobooks/Author - Title" "Author/Title"
      EOF
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --dry-run) dry_run=1; shift ;;
          -h|--help) usage; exit 0 ;;
          --) shift; break ;;
          -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
          *) break ;;
        esac
      done

      if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        usage >&2
        exit 2
      fi

      review_root=${lib.escapeShellArg reviewDir}
      library_root=${lib.escapeShellArg libraryDir}
      log_dir=${lib.escapeShellArg importStateDir}

      source_real=$(realpath -- "$1")
      if [ ! -d "$source_real" ]; then
        echo "Source is not a directory: $1" >&2
        exit 1
      fi

      if [ -L "$source_real" ]; then
        echo "Refusing to import symlink source: $source_real" >&2
        exit 1
      fi

      case "$source_real" in
        "$review_root"/*) ;;
        *)
          echo "Source must be under $review_root" >&2
          exit 1
          ;;
      esac

      symlink=$(find "$source_real" -type l -print -quit)
      if [ -n "$symlink" ]; then
        echo "Refusing to import tree containing symlink: $symlink" >&2
        exit 1
      fi

      source_name=$(basename -- "$source_real")
      dest_rel=''${2:-$source_name}

      case "$dest_rel" in
        ""|/*|..|../*|*/..|*/../*)
          echo "Destination must be a safe relative path, got: $dest_rel" >&2
          exit 1
          ;;
      esac

      dest="$library_root/$dest_rel"
      if [ -e "$dest" ]; then
        echo "Destination already exists: $dest" >&2
        exit 1
      fi

      echo "Import source:      $source_real"
      echo "Import destination: $dest"

      if [ "$dry_run" -eq 1 ]; then
        echo "Dry run only; no files changed."
        exit 0
      fi

      mkdir -p -- "$(dirname -- "$dest")" "$log_dir"
      mv -- "$source_real" "$dest"
      chgrp -R media "$dest"
      find "$dest" -type d -exec chmod 2775 {} +
      find "$dest" -type f -exec chmod 0664 {} +

      printf '%s\t%s\t%s\n' "$(date --iso-8601=seconds)" "$source_real" "$dest" >> "$log_dir/imports.log"
      echo "Imported. Scan the Audiobookshelf library if it does not pick up changes automatically."
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.media.enable && audiobookshelfService.enable) {
    homelab = {
      apps.audiobookshelf = {
        enable = true;
        inherit (audiobookshelfService) user group;
        serviceNames = [ "audiobookshelf" ];
        storageAccess = [ "media" ];
        sharedWriter = audiobookshelfService.umaskSharedWriter;
        state.paths = [ "/var/lib/audiobookshelf" ];
      };

      services.audiobookshelf.auth = {
        # Audiobookshelf has first-class web/mobile auth and uses Authorization
        # headers for its own API. Keep the reverse proxy public and let the
        # application own authentication instead of layering Caddy Basic Auth.
        group = lib.mkForce null;
        stripAuthorizationHeader = lib.mkForce false;
      };

      services.audiobookshelf.backup = {
        enable = lib.mkDefault true;
        paths = lib.mkDefault [ "/var/lib/audiobookshelf" ];
      };
    };

    services.audiobookshelf = {
      enable = true;
      inherit (audiobookshelfService) user group openFirewall;
      host = audiobookshelfService.upstream.host;
      port = audiobookshelfService.upstream.port;
    };

    environment.systemPackages = [
      audiobookReview
      audiobookImport
    ];

    systemd.tmpfiles.rules = [
      "d ${importStateDir} 0750 root media - -"
      "z ${importStateDir} 0750 root media - -"
    ];
  };
}
