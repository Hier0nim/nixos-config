# Restore Legion after a disk failure

Start by rebuilding Legion from the Nix configuration in Git. Restore the encrypted Clan vars too. Keep the Clan decryption identity, Borg repository key, and Storage Box SSH key somewhere safe outside Legion. You need them to decrypt the configuration and read the Borg repository.

Use the configured sub2 repository. Check a recent completed archive and extract representative state to a private temporary directory before relying on it. The recovery commands below overwrite configured paths; do not test them against live application state.

Once Legion boots with its usual configuration and the data disks are mounted at the expected paths, find the Borg archive you want to use:

```sh
clan backups list server-legion --provider borgbackup
```

Restore each service's saved state by replacing `<state-name>` with its name from the list:

```sh
clan backups restore server-legion borgbackup <archive-name> --service <state-name>
```

Use the same flake revision that made the backup, if you can. The restore command puts the saved files back. It does not run the application-specific steps below.

## Restore application state

For these services, restore the named state, then copy it into the live service directory with the helper:

```sh
sudo homelab-restore-state <authelia|copyparty-state|actual|enable-actual|audiobookshelf|listenarr|forgejo|jellyfin|seerr>
```

The helper takes an exclusive lock shared with application snapshots, stops the service, moves current data to a uniquely named rollback directory, and installs the restored files. It restarts only a previously active service. On copy or startup failure it attempts to restore the old data and previous active state. If it cannot stop the service or move the old data back, it fails with the rollback copy retained for manual recovery. Check the service before deleting a successful restore's rollback copy.

The saved states are named `copyparty-state`, `actual`, `enable-actual`, `audiobookshelf`, `listenarr`, `jellyfin`, `seerr`, and `forgejo-snapshot`. Restore `forgejo-snapshot` from Borg, then run `homelab-restore-state forgejo`.

Authelia is enabled, and `authelia` is snapshotted and accepted by the helper. Its enrolled state passed local and isolated offsite restore checks, including decryption, without restoring production state. Restore its user database and SQLite enrollment state together with the matching Clan Vars storage encryption key and any OIDC keys. The initial users seed is not a substitute for the live user database. Never rotate keys during a restore test.

## Restore other data

Sonarr, Sonarr Anime, Radarr, and Prowlarr save their own database backups. Restore `arr-backups` from Borg, start the app, and use its System > Backup > Restore page to load the ZIP you want. The Nix configuration reapplies the app's settings. The ZIP restores its catalogue and other saved app data.

Listenarr's saved state restores its catalogue. At startup, Nix reapplies its library path, qBittorrent client, quality profile, Prowlarr indexers, and copy behavior. The copy leaves completed torrents in place for seeding.

For Immich, stop `immich-server` and `immich-machine-learning`, then restore `immich-media`. Keep the restored `library`, `upload`, and `profile` directories at their original paths. Start Immich, then restore its database from the included Immich backup under Administration, Maintenance. Immich can rebuild thumbnails and encoded video, so those files are not in the backup.

For the NAS files, restore `copyparty` while Copyparty is stopped. Restore the matching `copyparty-state` snapshot and use the helper before starting Copyparty. That snapshot covers `/var/lib/copyparty`, including persistent key salts and the share database if sharing is later enabled. The file index can be rebuilt, but lost salts or share state can invalidate existing links. Older archives may not contain `copyparty-state`.

For Forgejo, restore `forgejo-snapshot` and run `homelab-restore-state forgejo` with the matching Nix configuration active.

## What this backup does not contain

The backup does not include `/data/media` or `/data/downloads`. Restore those from another copy or recreate them. The removed workstation's home and work files were not backed up and are not recoverable through this plan.

Beszel data and qBittorrent's active torrent queue are also not restored. Nix recreates the service configuration, but the queue itself is lost.
