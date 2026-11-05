# Restore Legion

Rebuild Legion from the Git revision that made the backup, then restore its encrypted Clan Vars. Keep the Clan decryption identity, Borg key and Storage Box SSH key somewhere outside Legion. A backup is not useful if its keys were lost with the server.

Mount the data disks at their usual paths. Use the configured Storage Box sub2 repository and choose a completed archive:

```sh
clan backups list server-legion --provider borgbackup
```

Before restoring live data, extract a few files into a private test directory and check them. The commands below overwrite configured paths; do not use them as a test against running applications.

## Put application state back

Restore one state from the archive, then let the local helper install it:

```sh
clan backups restore server-legion borgbackup <archive-name> --service <state-name>
sudo homelab-restore-state <state-name>
```

This works for `authelia`, `copyparty-state`, `actual`, `enable-actual`, `audiobookshelf`, `listenarr`, `jellyfin`, `seerr`, `ntfy`, `gatus`, `mealie`, `donetick` and `paperless`. Forgejo is the naming exception: restore `forgejo-snapshot`, then run `homelab-restore-state forgejo`.

The helper stops the application, keeps its current data in a rollback directory and copies in the saved state. It restarts the application only if it was running before. If the restore fails, it tries to put the old data back. Check the result before deleting the rollback copy.

Paperless is stopped as a group through `paperless-state.target`, including its web server, scheduler and task worker. Its snapshot contains the database and document files under `/data/.homelab-backup/paperless`. Keeping that copy on SATA avoids filling NVMe. The other household snapshots are under `/var/backup/homelab` and include their files, databases, accounts and tokens.

Restore each application's matching Clan Vars too. Do not generate replacement signing keys or OIDC credentials. Authelia needs its live user database, SQLite enrollment database and matching encryption/OIDC keys together. Its initial user seed is not a replacement for the live database. Old backups can also bring back revoked sessions.

After restoring, check login and a few real records. For Paperless, check a document and shared permissions. For Mealie and Donetick, check recipes and chores. For ntfy, check its account and cached messages. An isolated restore is the safe place to test this before a real disk failure.

## Restore the remaining data

For Sonarr, Sonarr Anime, Radarr and Prowlarr, restore `arr-backups`, start the app and load its ZIP through System > Backup > Restore. Nix reapplies configuration; the ZIP restores the catalogue. Listenarr also gets its configured library, clients and profiles back at startup. Its copy behavior leaves torrents in place for seeding.

For Immich, stop `immich-server` and `immich-machine-learning`, then restore `immich-media`. Keep `library`, `upload` and `profile` under `/data/photos`. Older archives put uploads under `/var/lib/homelab/immich-hot/upload`; copy those into `/data/photos/upload` before starting Immich. Then restore the included database backup through Administration > Maintenance. Thumbnails and encoded video can be rebuilt.

Do not boot a generation with the old Immich bind mounts. The old NVMe media copies are stale; a NixOS rollback does not move current files back.

For NAS files, stop Copyparty and restore `copyparty` with its matching `copyparty-state`. Install that state with the helper before starting Copyparty. Keep SQLite databases with their WAL files. The saved salts and share database cannot be replaced by rebuilding the file index. Older archives may lack this state.

If the NAS restore brings back old ownership, apply the declared tmpfiles rules before starting Copyparty. Its private `.hist` directories belong to `copyparty:copyparty`.

## Know what is missing

Media under `/data/media` and downloads under `/data/downloads` are not backed up. Neither are Beszel history, qBittorrent's active queue or the removed workstation's files.

BentoPDF has no server-side document archive. Homepage is rebuilt from Nix. Their browser access comes from the restored Authelia state, not from a separate application backup.
