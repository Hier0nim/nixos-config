# Restore Legion after a disk failure

Start by rebuilding Legion from the Nix configuration in Git. Restore the encrypted Clan vars too. Keep the Clan decryption identity, Borg repository key, and Storage Box SSH key somewhere safe outside Legion. You need them to decrypt the configuration and read the Borg repository.

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
sudo homelab-restore-state <actual|enable-actual|audiobookshelf|listenarr|forgejo|jellyfin|seerr>
```

The helper stops the service, moves its current data aside as a timestamped rollback copy, installs the restored files, and starts the service again. Check that the service works before deleting the rollback copy. If the restore fails, the helper keeps the old data so you can put it back.

The saved states are named `actual`, `enable-actual`, `audiobookshelf`, `listenarr`, `jellyfin`, `seerr`, and `forgejo-snapshot`. Restore `forgejo-snapshot` from Borg, then run `homelab-restore-state forgejo`.

## Restore other data

Sonarr, Sonarr Anime, Radarr, and Prowlarr save their own database backups. Restore `arr-backups` from Borg, start the app, and use its System > Backup > Restore page to load the ZIP you want. The Nix configuration reapplies the app's settings. The ZIP restores its catalogue and other saved app data.

Listenarr's saved state restores its catalogue. At startup, Nix reapplies its library path, qBittorrent client, quality profile, Prowlarr indexers, and copy behavior. The copy leaves completed torrents in place for seeding.

For Immich, stop `immich-server` and `immich-machine-learning`, then restore `immich-media`. Keep the restored `library`, `upload`, and `profile` directories at their original paths. Start Immich, then restore its database from the included Immich backup under Administration, Maintenance. Immich can rebuild thumbnails and encoded video, so those files are not in the backup.

For the NAS files, restore `copyparty` while Copyparty is stopped. Start Copyparty after the restore. It can rebuild its file index if needed.

For Forgejo, restore `forgejo-snapshot` and run `homelab-restore-state forgejo` with the matching Nix configuration active.

## What this backup does not contain

The backup does not include `/data/media`, `/data/downloads`, or `/var/lib/nixos-containers/workstation`. Restore those from another copy or recreate them. The workstation's home and work files are not part of this recovery plan.

Beszel data and qBittorrent's active torrent queue are also not restored. Nix recreates the service configuration, but the queue itself is lost.
