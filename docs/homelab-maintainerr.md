# Maintainerr cleanup

Maintainerr puts old media into cleanup collections. After **30 days** in a
collection, it deletes the files and stops Radarr/Sonarr from downloading them
again. The Radarr/Sonarr entries stay in place.

## What gets selected

- **Watched movies:** added at least 180 days ago, watched by either user, and
  not played for 180 days.
- **Never-played movies:** added at least 365 days ago, not marked watched, and
  never started, even briefly.
- **Shows and Anime:** Sonarr says the series has ended, and every available
  episode has been watched. The series and its newest episode must have been
  added at least 180 days ago, with no playback for 180 days.

Watch history counts both `admin` and `pieczarkowo`. Either user can have watched
an episode; both do not need to finish it. Missing episodes do not count, and
empty series are excluded. Unfinished playback also counts as recent activity.

Rules refresh hourly. Deletion runs daily at 05:30 in Maintainerr's timezone.
Check the collections yourself; this setup does not send warning emails.

## How to keep something

Either:

- Favorite it in Jellyfin. For TV and Anime, favorite the **series**, not an episode.
- Add the `keep` tag to its entry in Radarr, Sonarr, or Sonarr Anime.

Wait for a rules refresh and confirm it leaves the cleanup collection. If
deletion is close, pause cleanup or add a Maintainerr exclusion instead.
Do not manually add titles to the automatic cleanup collections.

After cleanup, Maintainerr adds the title to its exclusion list. To download it
again, you may need to clear the exclusion and turn monitoring back on. Forced
Seerr cleanup is disabled.

## Apply and review

1. Protect anything you want to keep with favorites or `keep` tags.
2. Run `nh os switch ./`.
3. Check the setup services:

   ```bash
   systemctl status maintainerr-settings maintainerr-rules
   ```

4. After the first hourly run, review the four `Cleanup - ...` collections.
   Protect any unwanted matches before their 30 days expire.

Edit the policy in
[`maintainerr-rules.nix`](../modules/nixos/homelab/services/maintainerr-rules.nix).
Nixflix removes rule groups that are not declared there, so UI-only rules will
not survive the next configuration run.

Deleting media may not free space while qBittorrent keeps a hardlinked copy for
seeding. These rules do not delete torrents or download files.

## Check changes

```bash
nix build .#checks.x86_64-linux.maintainerr-cleanup-policy-regression --no-link
```

This checks the rules, protections and 30-day delay without deleting anything.
It does not verify which titles will match or whether watch history is accurate.

The rule IDs come from Maintainerr 3.30.1. After an upgrade, also check them
against the running server:

```bash
nix eval --json .#nixosConfigurations.server-legion.config.nixflix.maintainerr.rules \
  > /tmp/maintainerr-rules.json
curl -fsS http://127.0.0.1:6246/api/rules/constants \
  > /tmp/maintainerr-constants.json
python3 scripts/test-maintainerr-rules.py \
  /tmp/maintainerr-rules.json /tmp/maintainerr-constants.json
```
