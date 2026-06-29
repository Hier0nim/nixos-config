# Audiobook Flow

The homelab audiobook setup is intentionally a curated lane instead of a full
Readarr-style automation pipeline. Audiobookshelf is the source of truth for the
library, Prowlarr is used for authorized manual search/discovery, and
qBittorrent is only the downloader.

Use only sources and content you are authorized to access.

## Architecture

```text
Prowlarr manual search
  -> qBittorrent category: audiobooks
  -> /data/downloads/torrent/audiobooks
  -> human review
  -> /data/downloads/review/audiobooks
  -> audiobook-import
  -> /data/media/audiobooks
  -> Audiobookshelf scan/playback
```

Readarr is not part of the default architecture. It is archived upstream and has
shown compatibility issues with qBittorrent 5.x, while audiobook metadata and
source quality usually need manual review anyway.

## Declarative pieces

The NixOS configuration owns:

- Audiobookshelf service and reverse proxy at `audiobooki.<domain>`.
- Audiobookshelf state backup for `/var/lib/audiobookshelf`.
- qBittorrent category:

  ```text
  audiobooks -> /data/downloads/torrent/audiobooks
  ```

- Prowlarr download-client category for manual grabs:

  ```text
  prowlarr -> audiobooks
  ```

- Shared storage directories:

  ```text
  /data/downloads/torrent/audiobooks
  /data/downloads/review/audiobooks
  /data/media/audiobooks
  ```

- `audiobook-review`, a conservative helper command for copying completed
  qBittorrent downloads into the review staging directory while leaving the
  torrent copy untouched for seeding.
- `audiobook-import`, a conservative helper command for moving reviewed folders
  into the Audiobookshelf library.

The NixOS configuration also declares selected Prowlarr indexers. Because
`prowlarr-indexers.service` reconciles the Prowlarr indexer list from Nix,
indexers added only in the UI may be removed on the next activation. Add
long-lived indexers in `services/nixflix.nix`.

## Manual pieces

The UI/manual workflow owns:

- Choosing releases in Prowlarr.
- Deciding whether a completed download is correct and complete.
- Renaming/restructuring the audiobook folder.
- Choosing final author/title/series layout.
- Fixing Audiobookshelf metadata matches.

Do not put unreviewed downloads directly into `/data/media/audiobooks`.

## qBittorrent and seeding

qBittorrent stores audiobook grabs in:

```text
/data/downloads/torrent/audiobooks
```

Do not move files out of qBittorrent's managed directory while the torrent is
still active. To keep seeding, copy the completed folder to the review directory
with `audiobook-review`; the qBittorrent copy remains untouched. If you do not
need to keep seeding, remove the torrent from qBittorrent while keeping files,
then move the folder to the review directory manually.

## Review and import

Review folder:

```text
/data/downloads/review/audiobooks
```

Suggested reviewed folder names:

```text
/data/downloads/review/audiobooks/Author - Title
/data/downloads/review/audiobooks/Author - Series 01 - Title
```

Copy a completed qBittorrent download into review without touching the seeded
torrent copy:

```sh
audiobook-review --dry-run \
  "/data/downloads/torrent/audiobooks/Downloaded Release Name" \
  "Terry Pratchett - Guards! Guards!"

sudo audiobook-review \
  "/data/downloads/torrent/audiobooks/Downloaded Release Name" \
  "Terry Pratchett - Guards! Guards!"
```

The review helper uses `cp -a --reflink=auto`: on filesystems with reflink
support it initially avoids a full duplicate copy while remaining copy-on-write;
otherwise it makes a normal copy.

Dry-run an import:

```sh
audiobook-import --dry-run \
  "/data/downloads/review/audiobooks/Author - Title" \
  "Author/Title"
```

Import:

```sh
sudo audiobook-import \
  "/data/downloads/review/audiobooks/Author - Title" \
  "Author/Title"
```

The destination is relative to:

```text
/data/media/audiobooks
```

The helper refuses symlinks and existing destinations, then normalizes imported
permissions:

```text
directories: 2775
files:       0664
group:       media
```

The helpers also log actions to:

```text
/var/lib/homelab/audiobook-import/reviews.log
/var/lib/homelab/audiobook-import/imports.log
```

## Audiobookshelf setup

In Audiobookshelf, create an audiobook library pointing at:

```text
/data/media/audiobooks
```

The public reverse proxy for `audiobooki.<domain>` intentionally does not use
homelab/Caddy Basic Auth. Audiobookshelf owns authentication itself so its web
UI, mobile clients, WebSocket/API traffic, and `Authorization` headers work
without a second proxy-auth layer. Keep registration closed unless explicitly
needed and use strong Audiobookshelf user passwords.

Audiobookshelf UI state is stored in `/var/lib/audiobookshelf`, which is managed
as private service state and included in homelab backups. The individual
audiobook files live under `/data/media/audiobooks`; large media backup policy is
separate from service-state backup policy.

## ABtorrents

ABtorrents is available as an opt-in declarative Prowlarr indexer for authorized
accounts. It uses browser cookie authentication. Enable it only after storing the
cookie in SOPS:

```sh
sops set secrets/server-legion/media.yaml '["abtorrents_cookie"]' '"cookie=value; other=value"'
```

Then enable the indexer in Nix:

```nix
homelab.services.prowlarr.indexers.abtorrents.enable = true;
```

This uses a small homelab `prowlarr-indexer-abtorrents.service` instead of
`nixflix.prowlarr.config.indexers`, because nixflix's generic indexer reconciler
only handles runtime SOPS secrets for `apiKey`, `username`, and `password`;
ABtorrents needs a secret `cookie` field.

To get the cookie, log in to ABtorrents in a browser, keep the session persistent
where appropriate, open developer tools, reload a torrent/search page, and copy
the complete `cookie:` request header value.

The Nix config enables conservative private-tracker settings:

- freeleech-only searches by default,
- at least one seeder,
- seed ratio target `2.0`,
- seed time target `7` days,
- pack seed time target `14` days,
- no magnet preference.

Always follow the tracker's current rules; adjust the declarative settings if
the rules require longer seeding or different limits.
