# Legion access and maintenance

Start with `services/proxy/default.nix` and each service's module when changing an address or upstream. `services/proxy/ingress.nix` builds the Caddy routes, `services/identity/` configures Authelia and OIDC, and `dns/` manages Cloudflare records. The running route list is `/etc/homelab-ingress/services.tsv`.

## Who can sign in

Authelia has four application-access groups. `household` is for shared everyday apps, `finance` protects Actual, `media-admin` protects media management, and `infra-admin` protects server administration. The initial configuration puts Hieronim in all four and Sarcia in `household` and `finance`.

The live `/var/lib/authelia-homelab/users_database.yml` is authoritative. Editing the encrypted seed does not change existing users. Make later changes as root, preserve Authelia ownership and mode `0600`, and replace the file atomically. Authelia watches it.

Files and photos already use household admission. Actual requires finance membership; Sarcia has access to the existing budget without owning it. Forgejo and Beszel admit Hieronim with `infra-admin`. Their existing native accounts and recovery paths remain unchanged. Jellyfin, Audiobookshelf and Seerr keep native login, including the shared Audiobookshelf account. `auth = "native"` delegates authentication to the app; it does not make it anonymous.

Media management, the shell and Actual automation use proxy authentication. Browser admission does not grant native administrator rights. Existing API-key/session authentication remains in place. API exceptions match `/api` and `/api/*`, not `/api*`; Prowlarr has no public API exception. qBittorrent keeps native login behind its gate at `/qbittorrent/`.

For the new household apps, Hieronim uses MFA and Sarcia uses her password. Existing app policies stay as configured. New Mealie and Donetick accounts map `infra-admin` to application administration; Donetick maps other household members to manager. ntfy is separate: it uses native credentials, denies anonymous access, and lets Hieronim read `infra` while Gatus can only publish. The detailed status page is Hieronim-only; Homepage's links grant no access to their targets.

Authelia logout ends the IdP session, not every application's own session. Existing tokens may survive a group change. Keep the original native identities and account links when changing admission rules.

## First login to the new apps

The addresses are `dokumenty`, `przepisy`, `todo`, `pdf`, `ntfy` and `status` under `pieczarkowo.me`. Homepage is at `pieczarkowo.me`. Check sharing and privacy before uploading household data.

Sign in to Paperless as both users, then run `paperless-manage shell` as root to give the household its document permissions and make Hieronim the administrator:

```python
from django.contrib.auth.models import Group, Permission, User
household, _ = Group.objects.get_or_create(name="household")
household.permissions.set(Permission.objects.filter(
    content_type__app_label="documents",
    content_type__model__in=["document", "tag", "correspondent", "documenttype", "note", "customfield", "uisettings", "savedview"],
))
admin = User.objects.get(username="hieronim")
for user in User.objects.filter(username__in=["hieronim", "sarcia"]):
    user.groups.add(household)
admin.is_staff = admin.is_superuser = True
admin.set_unusable_password()
admin.save()
```

In Paperless, create an unfiltered workflow for newly added documents that gives `household` view and edit access. The group's global delete permission allows deletion too. Model permissions alone do not share existing document objects. Test an upload from each account and deletion as Sarcia. Use a maintained community Android scanner with a native API token. Hieronim's chosen administrator token gives his phone administrator access, not a restricted scanning role.

In Mealie, confirm both users are in `Home` / `Family`. As Hieronim, remove the seeded local account, enable his household-management/organize permissions, and give Sarcia organize permission without user administration or invitations. Keep the group and household private, disable default public recipes, and do not create public cookbooks or share links. Check recipes, meal plans and shopping lists from both accounts. Install its PWA on the phones if wanted.

In Donetick, confirm both users share `Home`, Hieronim is admin and Sarcia is manager. The official Android app uses `todo.pieczarkowo.me`; test its browser-to-app OIDC return on both phones. Self-hosted push reminders are not verified or configured through a bridge.

Keep ordinary browser login SSO-only. Recover OIDC access through SSH and the matching Authelia membership, credentials and saved state, not by leaving a local browser administrator enabled. Paperless's native management shell remains available for account repair.

BentoPDF processes documents in the browser. Some tools download optional engines from jsDelivr; they do not upload documents for processing. ntfy's password/token is in root-only Clan Vars. Test background delivery and delivery after a phone restart. Its live cache lasts seven days; old encrypted Borg archives follow the separate backup retention.

Gatus checks internal services every minute and reports one failure after three failed checks, then a recovery after two successes. Backup failures report immediately; a missing report becomes overdue after 26 hours. Check a normal scheduled backup and one controlled alert/recovery after deployment. Legion cannot report its own power loss or total internet outage without an external monitor.

## Keep credentials and private routes private

Keep existing generator names, credentials and ownership. Do not regenerate keys to reorganize files. Use encrypted Clan Vars and runtime credentials, never plaintext Nix values, command arguments or logs. For an approved SMTP credential replacement, use the hidden prompt:

```sh
CLAN_NO_COMMIT=1 nix develop --command clan vars generate server-legion --generator authelia-smtp --no-regenerate
```

Actual's backend on `127.0.0.1:3101` admits only root/Caddy. Enable-Actual retains its saved `http://127.0.0.1:3100` target; Caddy supplies the existing automation credential. Do not accept public passwords or incoming `X-Actual-Password`. Keep `actual-local-guard.service` and Caddy's private Unix admin socket under `/run/caddy`; do not open a TCP admin listener.

Copyparty trusts browser identity only after Caddy authentication and its private proof. Keep `copyparty-local-guard.service`. Strip incoming identity/proof headers and do not return native `Set-Cookie` through SSO, since its SID is reusable. Native Basic and OPTIONS/PROPFIND still reach the native challenge. The `idp-h-key` credential is a secret header name; Caddy's staged proof file stays mode `0400`.

Copyparty's canonical private path is `/data/nas/sarcia`, mounted at `/nas/sarcia`. Keep its original generator and `sarka-password`. Password-only Basic ignores the supplied username; do not enable `--usernames` as incidental cleanup. Guest sharing stays disabled. A NixOS rollback does not reverse this directory rename; never overwrite an unexpected destination.

Forgejo reads its setup client secret from the environment rather than argv. Its saved `.authelia-source` fingerprint avoids unnecessary source updates on restart. Do not edit that owned OAuth source by hand. Beszel relinking recovery is retained in NIXOS-0023 artifact A000002.

Caddy access logs are off and its error logger omits request URLs and headers. Native app logs can still contain sensitive data. Inspect selected fields instead of pasting raw journals or callback URLs.

## Change DNS and certificates

Only Authelia uses Legion's Cloudflare Tunnel. Application CNAMEs are DNS-only and point to `yze78b4.glddns.com`. Mail, ACME and undeclared records stay unmanaged. `ha.pieczarkowo.me` belongs to a separate tunnel; do not adopt it.

The auth origin checks the actual peer before trusting headers. Only loopback cloudflared may supply `CF-Connecting-IP`; it validates origin HTTPS with matching SNI/Host and a final 404. Do not replace those checks with general forwarded-header trust.

The existing certificate covers the apex and all first-level subdomains. Caddy reads the certificate, not the Cloudflare token. Keep that token in `cloudflare-dns/api-token`, scoped to Zone Read and DNS Edit for this zone. The ACME renewal timer handles renewal; preserve its state during rollback.

From the repository root, prepare and review a saved DNS plan:

```sh
nix run .#legion-dns -- init -input=false
nix run .#legion-dns -- plan -out=review.tfplan
nix run .#legion-dns -- show review.tfplan
```

After separate approval, apply that exact plan with `nix run .#legion-dns -- apply review.tfplan`. Applying a saved plan does not ask again and can partly succeed before failing. The wrapper keeps the token in the provider environment. Its state and relative plans live under `$XDG_STATE_HOME/nixos-config/legion-dns/operator`, normally `~/.local/state/nixos-config/legion-dns/operator`, with private directory/file modes `0700`/`0600`.

If state is lost, restore its backup. Otherwise inspect Cloudflare read-only and import only the declared records by their exact IDs. Do not delete/recreate records or adopt unrelated ones. Restoring OpenTofu state does not undo DNS changes.

The router reserves `192.168.8.2` for Legion and uses these dnsmasq rules:

```text
address=/*.pieczarkowo.me/192.168.8.2
server=/*.pieczarkowo.me/
server=/_acme-challenge.pieczarkowo.me/#
server=/_domainkey.pieczarkowo.me/#
server=/_dmarc.pieczarkowo.me/#
server=/ha.pieczarkowo.me/#
```

The empty server rule prevents public CNAMEs overriding local routing. The `#` exceptions use AdGuard Home at `127.0.0.1:3053`. This wildcard does not handle the apex, and browser DoH can bypass router DNS. Check apex resolution before accepting Homepage on the LAN. Router/DNS changes need their own approval.

## Activate and check

Run `nix flake check` and `nix develop --command pre-commit run --all-files`, then review the build against the current system before an approved deployment. Keep SSH recovery, a protected prior generation and verified backups. See `backup-restore.md` for restore commands and exclusions.

A rollback does not undo account links, budget ownership, DNS changes or filesystem renames. Do not restore databases automatically during activation. Actual and Copyparty guards own only their chains; never clear the whole firewall to repair them.

Enable-Actual keeps host networking, its loopback-only UI and `PUBLIC_URL=https://actual-sync.pieczarkowo.me`. The pinned image ignores `ACTUAL_URL`; use its supported settings/API to change a saved target. Do not force a banking import as a test or generalize this container's networking workaround.

After a network change, test DNS and HTTPS as each daemon's actual UID inside its mount/network/root namespaces. `ip netns exec wg` alone can use a different resolver view and miss the problem. Do not change credentials, endpoints or global DNS to mask an unexplained failure.
