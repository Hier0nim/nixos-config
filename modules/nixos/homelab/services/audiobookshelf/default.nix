{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  audiobookshelfService = cfg.services.audiobookshelf;
  audiobookImportDashboardService = cfg.services."audiobook-imports";
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
      if [ "$(id -u)" -eq 0 ]; then
        chgrp -R media "$dest"
        find "$dest" -type d -exec chmod 2775 {} +
        find "$dest" -type f -exec chmod 0664 {} +
      else
        echo "Not running as root; relying on existing group-writable media permissions." >&2
      fi

      printf '%s\t%s\t%s\n' "$(date --iso-8601=seconds)" "$source_real" "$dest" >> "$log_dir/reviews.log"
      echo "Copied for review. Keep the original qBittorrent torrent active until tracker obligations are satisfied."
    '';
  };

  audiobookImport = pkgs.writeShellApplication {
    name = "audiobook-import";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.ffmpeg
    ];
    text = ''
      set -euo pipefail

      dry_run=0
      auto=0

      # ── Extract author + title from embedded audio tags ──────────────────
      extract_tags() {
        local dir="$1"
        local audio_file

        # Find first audio file in the directory
        audio_file=$(find "$dir" -maxdepth 2 -type f \( -name '*.m4b' -o -name '*.m4a' -o -name '*.mp3' -o -name '*.flac' -o -name '*.ogg' \) | head -n1)

        if [[ -z "$audio_file" ]]; then
          echo ""
          return 1
        fi

        # Extract artist (author) and book title via ffprobe
        # Prefer 'album' over 'title' — 'title' often contains chapter names
        local artist title album
        artist=$(ffprobe -v quiet -show_entries format_tags=artist -of csv=p=0 "$audio_file" 2>/dev/null | head -n1)
        album=$(ffprobe -v quiet -show_entries format_tags=album -of csv=p=0 "$audio_file" 2>/dev/null | head -n1)
        title=$(ffprobe -v quiet -show_entries format_tags=title -of csv=p=0 "$audio_file" 2>/dev/null | head -n1)

        # For MP4/M4B, try iTunes-style tags if standard tags are empty
        if [[ -z "$artist" ]]; then
          artist=$(ffprobe -v quiet -show_entries format_tags=album_artist -of csv=p=0 "$audio_file" 2>/dev/null | head -n1)
        fi

        # Use album (book title) if available, otherwise fall back to title (chapter name)
        local book_title="''${album:-$title}"

        # Clean up common suffixes like "(Unabridged)", "(Abridged)"
        book_title=$(echo "$book_title" | sed -E 's/ *\((Unabridged|Abridged)\)$//')

        # Return as "artist\ttitle"
        if [[ -n "$artist" && -n "$book_title" ]]; then
          printf '%s\t%s' "$artist" "$book_title"
          return 0
        fi

        echo ""
        return 1
      }

      usage() {
        cat <<'EOF'
      Usage: audiobook-import [--dry-run] [--auto] SOURCE [DESTINATION]
      Usage: audiobook-import --all [--dry-run] [--auto]

      Move one or all reviewed audiobook directories into the Audiobookshelf library.

      SOURCE must be a directory under:
        ${reviewDir}

      DESTINATION is optional and relative to:
        ${libraryDir}

      Options:
        --dry-run  Show what would happen without moving files.
        --auto     Auto-detect Author/Title from embedded audio tags (via ffprobe).
        --all      Import all directories in the review staging folder.

      Examples:
        audiobook-import --dry-run "${reviewDir}/Author - Title"
        audiobook-import --auto "${reviewDir}/Author - Title"
        audiobook-import --all --auto --dry-run
        audiobook-import "${reviewDir}/Author - Title" "Author/Title"
      EOF
      }

      # ── Import a single source into the library ──────────────────────────
      import_one() {
        local source_path="$1"
        local dest_override=''${2:-}

        local review_root=${lib.escapeShellArg reviewDir}
        local library_root=${lib.escapeShellArg libraryDir}
        local log_dir=${lib.escapeShellArg importStateDir}

        local source_real
        source_real=$(realpath -- "$source_path")
        if [ ! -d "$source_real" ]; then
          echo "Source is not a directory: $source_path" >&2
          return 1
        fi

        if [ -L "$source_real" ]; then
          echo "Refusing to import symlink source: $source_real" >&2
          return 1
        fi

        case "$source_real" in
          "$review_root"/*) ;;
          *)
            echo "Source must be under $review_root" >&2
            return 1
            ;;
        esac

        local symlink
        symlink=$(find "$source_real" -type l -print -quit)
        if [ -n "$symlink" ]; then
          echo "Refusing to import tree containing symlink: $symlink" >&2
          return 1
        fi

        local dest_rel

        # Auto-detect from embedded tags if requested and no manual override
        if [[ "$auto" -eq 1 && -z "$dest_override" ]]; then
          local tag_result
          if tag_result=$(extract_tags "$source_real"); then
            local tag_artist tag_title
            tag_artist=$(echo "$tag_result" | cut -f1)
            tag_title=$(echo "$tag_result" | cut -f2)
            dest_rel="''${tag_artist}/''${tag_title}"
            echo "  Auto-detected: $dest_rel" >&2
          else
            echo "  No embedded tags found, using folder name." >&2
            local source_name
            source_name=$(basename -- "$source_real")
            dest_rel="$source_name"
          fi
        else
          dest_rel="''${dest_override:-$(basename -- "$source_real")}"
        fi

        case "$dest_rel" in
          ""|/*|..|../*|*/..|*/../*)
            echo "Destination must be a safe relative path, got: $dest_rel" >&2
            return 1
            ;;
        esac

        local dest
        dest="$library_root/$dest_rel"
        if [ -e "$dest" ]; then
          echo "Destination already exists: $dest" >&2
          return 1
        fi

        echo "Import source:      $source_real"
        echo "Import destination: $dest"

        if [ "$dry_run" -eq 1 ]; then
          echo "Dry run only; no files changed."
          return 0
        fi

        mkdir -p -- "$(dirname -- "$dest")" "$log_dir"
        mv -- "$source_real" "$dest"
        if [ "$(id -u)" -eq 0 ]; then
          chgrp -R media "$dest"
          find "$dest" -type d -exec chmod 2775 {} +
          find "$dest" -type f -exec chmod 0664 {} +
        else
          echo "  Not running as root; relying on existing group-writable media permissions." >&2
        fi

        printf '%s\t%s\t%s\n' "$(date --iso-8601=seconds)" "$source_real" "$dest" >> "$log_dir/imports.log"
        echo "Imported."
      }

      # ── Argument parsing ─────────────────────────────────────────────────
      all_mode=0
      positional=()

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --dry-run) dry_run=1; shift ;;
          --auto) auto=1; shift ;;
          --all) all_mode=1; shift ;;
          -h|--help) usage; exit 0 ;;
          --) shift; break ;;
          -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
          *) positional+=("$1"); shift ;;
        esac
      done

      while [ "$#" -gt 0 ]; do
        positional+=("$1"); shift
      done

      review_root=${lib.escapeShellArg reviewDir}
      library_root=${lib.escapeShellArg libraryDir}

      # ── All mode: import every folder in review staging ──────────────────
      if [ "$all_mode" -eq 1 ]; then
        if [ "''${#positional[@]}" -gt 0 ]; then
          echo "--all does not accept positional arguments." >&2
          exit 2
        fi

        shopt -s nullglob
        entries=("$review_root"/*/)
        shopt -u nullglob

        if [ "''${#entries[@]}" -eq 0 ]; then
          echo "No folders found in $review_root"
          exit 0
        fi

        echo "Importing ''${#entries[@]} folder(s) from review staging..."
        echo ""

        failed=0
        for entry in "''${entries[@]}"; do
          echo "── $(basename "$entry") ──"
          if ! import_one "$entry" ""; then
            echo "  ⚠ Failed, skipping." >&2
            failed=$((failed + 1))
          fi
          echo ""
        done

        if [ "$failed" -gt 0 ]; then
          echo "$failed folder(s) failed to import." >&2
          exit 1
        fi

        if [ "$dry_run" -eq 0 ]; then
          echo "All imports complete. Scan Audiobookshelf if titles don't appear automatically."
        else
          echo "Dry run complete. No files were changed."
        fi
        exit 0
      fi

      # ── Single mode ─────────────────────────────────────────────────────
      if [ "''${#positional[@]}" -lt 1 ] || [ "''${#positional[@]}" -gt 2 ]; then
        usage >&2
        exit 2
      fi

      import_one "''${positional[0]}" "''${positional[1]:-}"
    '';
  };

  audiobookImportDashboard = pkgs.replaceVarsWith {
    src = ./dashboard.py;
    name = "audiobook-import-dashboard";
    isExecutable = true;
    replacements = {
      python = "${pkgs.python3}/bin/python3";
    };
  };

  audiobookImportDashboardTest =
    pkgs.runCommand "audiobook-import-dashboard-test"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
                set -euo pipefail
                export AUDIOBOOK_TORRENT_DIR="$TMPDIR/torrent"
                export AUDIOBOOK_REVIEW_DIR="$TMPDIR/review"
                export AUDIOBOOK_LIBRARY_DIR="$TMPDIR/library"
                export AUDIOBOOK_IMPORT_STATE_DIR="$TMPDIR/state"
        printf '%s\n' '#!/bin/sh' 'echo "review command: $@"' > "$TMPDIR/review-cmd"
                chmod +x "$TMPDIR/review-cmd"
                export AUDIOBOOK_IMPORT_CMD=/bin/false
                export AUDIOBOOK_REVIEW_CMD="$TMPDIR/review-cmd"
                export AUDIOBOOK_IMPORT_DASHBOARD_HOST=127.0.0.1
                export AUDIOBOOK_IMPORT_DASHBOARD_PORT=18081

                mkdir -p "$AUDIOBOOK_TORRENT_DIR/Torrent Book" "$AUDIOBOOK_REVIEW_DIR/Book One" "$AUDIOBOOK_LIBRARY_DIR" "$AUDIOBOOK_IMPORT_STATE_DIR"
                printf audio > "$AUDIOBOOK_REVIEW_DIR/Book One/chapter.m4b"
                printf audio > "$AUDIOBOOK_TORRENT_DIR/Torrent Book/chapter.m4b"
                printf '2026-01-01T00:00:00Z\t/src\t/dest\n' > "$AUDIOBOOK_IMPORT_STATE_DIR/imports.log"

                python -m py_compile ${audiobookImportDashboard}
                ${audiobookImportDashboard} > "$TMPDIR/server.log" 2>&1 &
                server=$!
                trap 'kill "$server" 2>/dev/null || true' EXIT

                ready=0
                for _ in $(seq 1 50); do
                  if python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:18081/', timeout=1).read()"; then
                    ready=1
                    break
                  fi
                  sleep 0.1
                done
                if [ "$ready" -ne 1 ]; then
                  cat "$TMPDIR/server.log" >&2
                  exit 1
                fi

                python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:18081/', timeout=2).read().decode())" > "$TMPDIR/page.html"
                grep -q 'Book One' "$TMPDIR/page.html"
                grep -q 'Torrent Book' "$TMPDIR/page.html"
                grep -q 'Recent imports' "$TMPDIR/page.html"

        python -c "import urllib.parse, urllib.request; data = urllib.parse.urlencode({'name': 'Torrent Book', 'mode': 'dry-run'}).encode(); print(urllib.request.urlopen('http://127.0.0.1:18081/review', data=data, timeout=2).read().decode())" > "$TMPDIR/review-result.html"
                grep -q 'review command:' "$TMPDIR/review-result.html"
        printf '%s\n' \
          'import urllib.error' \
          'import urllib.request' \
          'req = urllib.request.Request(' \
          '    "http://127.0.0.1:18081/import-all",' \
          '    data=b"mode=dry-run",' \
          '    headers={"Origin": "http://evil.example"},' \
          '    method="POST",' \
          ')' \
          'try:' \
          '    urllib.request.urlopen(req, timeout=2)' \
          'except urllib.error.HTTPError as exc:' \
          '    assert exc.code == 403, exc.code' \
          'else:' \
          '    raise SystemExit("cross-origin POST was not rejected")' \
          > "$TMPDIR/csrf_test.py"
                python "$TMPDIR/csrf_test.py"

                touch "$out"
      '';
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

      apps."audiobook-imports" = {
        inherit (audiobookImportDashboardService) enable user group;
        manageUser = true;
        serviceNames = [ "audiobook-import-dashboard" ];
        storageAccess = [
          "downloads"
          "media"
        ];
        sharedWriter = true;
        state = {
          paths = [ importStateDir ];
          mode = "0770";
        };
      };

      services = {
        audiobookshelf = {
          auth = {
            # Audiobookshelf has first-class web/mobile auth and uses Authorization
            # headers for its own API. Keep the reverse proxy public and let the
            # application own authentication instead of layering Caddy Basic Auth.
            group = lib.mkForce null;
            stripAuthorizationHeader = lib.mkForce false;
          };

          backup = {
            enable = lib.mkDefault true;
            paths = lib.mkDefault [ "/var/lib/audiobookshelf" ];
          };
        };

        "audiobook-imports".enable = lib.mkDefault true;
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

    system.extraDependencies = [ audiobookImportDashboardTest ];

    systemd.services."audiobook-import-dashboard" = lib.mkIf audiobookImportDashboardService.enable {
      description = "Audiobook import dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      unitConfig.RequiresMountsFor = [
        torrentDir
        reviewDir
        libraryDir
        importStateDir
      ];

      environment = {
        AUDIOBOOK_TORRENT_DIR = torrentDir;
        AUDIOBOOK_REVIEW_DIR = reviewDir;
        AUDIOBOOK_LIBRARY_DIR = libraryDir;
        AUDIOBOOK_IMPORT_STATE_DIR = importStateDir;
        AUDIOBOOK_IMPORT_CMD = "${audiobookImport}/bin/audiobook-import";
        AUDIOBOOK_REVIEW_CMD = "${audiobookReview}/bin/audiobook-review";
        AUDIOBOOK_IMPORT_DASHBOARD_HOST = audiobookImportDashboardService.upstream.host;
        AUDIOBOOK_IMPORT_DASHBOARD_PORT = toString audiobookImportDashboardService.upstream.port;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${audiobookImportDashboard}";
        User = audiobookImportDashboardService.user;
        Group = audiobookImportDashboardService.group;
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          torrentDir
          reviewDir
          libraryDir
          importStateDir
        ];
      };
    };

  };
}
