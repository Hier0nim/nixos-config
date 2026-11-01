# Legion ingress and identity

## Where to edit

- `services/proxy/default.nix` lists application upstreams, browser admission groups and public transports. `proxy/ingress.nix` renders ordinary Caddy routes.
- `services/identity/default.nix` configures Authelia, SMTP, sessions, the initial user seed and browser admission policies.
- Each native OIDC application's directory owns its client, authorization policy, credentials and application settings. `identity/generate-oidc-client.py` generates new client credentials only when explicitly invoked through Clan.
- `services/certificates.nix` owns wildcard issuance and renewal. Caddy uses the certificate but does not load the Cloudflare API token.
- `dns/` generates the managed Cloudflare records and provides the OpenTofu wrapper. Checks are declared in `checks/default.nix`, not the top-level flake.

`/etc/homelab-ingress/services.tsv` is a read-only route inventory. `auth = "native"` delegates authentication to the application; it does not mean anonymous access.

## Authentication boundaries

Sonarr, Sonarr Anime, Radarr, Prowlarr, Listenarr, Maintainerr, qBittorrent, ttyd and Enable-Actual use Authelia browser gates. Servarr External UI mode trusts Caddy inside its isolated backend boundary. Native keys/sessions still authenticate API requests. Exceptions match `/api` and `/api/*`, never `/api*`. Prowlarr has no public API exception. qBittorrent stays under `/qbittorrent/`, stripped upstream, and retains native login behind the gate.

Household admission requires one factor. Administrative and finance groups require MFA, except Sarcia's rule matches both her username and the required group. It grants no additional membership or native administrator role. Hieronim's MFA remains required. Proxy admission and application permissions are separate.

Immich, Actual, Forgejo and Beszel use native OIDC and their original native identities. Automatic registration and role synchronization remain disabled where configured. Audiobookshelf retains its shared account and native login. Jellyfin, Seerr, Git SSH/LFS, runners and native clients retain application-owned authentication.

Immich's original Hieronim and Sarcia accounts are linked. Public sharing works. Sarcia's phone sign-in/background uploads remain deferred in NIXOS-0024. Forgejo's original `Hier0nim` administrator and Beszel's existing administrator are linked and accepted. Their native password recovery paths remain. Beszel's completed linking page is retired; NIXOS-0023 artifact A000002 retains a relinking recovery recipe. Matching the native email to the IdP is not required for an existing link.

Actual's Hieronim account owns the existing budget. Sarcia is BASIC, not an owner, and has an explicit grant to that budget. The original privileged automation identity remains private. Enable-Actual keeps `http://127.0.0.1:3100`; root-only Caddy injects the existing automation credential and forwards to Actual on `127.0.0.1:3101`, restricted to root/Caddy. Public password authentication and incoming `X-Actual-Password` are denied. Preserve `actual-local-guard.service` and the private Caddy Unix admin socket under `/run/caddy` mode `0700`. No TCP admin listener.

Copyparty's browser route admits only `hieronim` and `sarcia` after household authentication. Fixed native ACLs control files. Native Basic and OPTIONS/PROPFIND reach the native challenge without browser redirects. Caddy strips incoming identity/proof headers and supplies the runtime proof only after browser admission. SSO responses must not expose `Set-Cookie`; even an expired native cookie contains a reusable SID. `copyparty-local-guard.service` restricts the trusted-header backend to root/Caddy.

Copyparty guest sharing remains disabled. NIXOS-0026 retains the previous conditional route/test work and tracks enabling sharing separately. Windows/rclone reconnect and transfer are deferred in NIXOS-0024. The NixOS client works.

Authelia logout at `https://auth.pieczarkowo.me/logout` ends the IdP session, not independent native application sessions. Existing app tokens may outlive an admission-group change.

## Runtime credentials and maintenance

Keep generator names, stored credentials and ownership unchanged. Do not regenerate keys to reorganize configuration. Secrets belong in encrypted Clan Vars and runtime credentials, never Nix values, argv or logs.

Authelia's live `/var/lib/authelia-homelab/users_database.yml` is authoritative after initial seeding. Changing the encrypted seed does not update live users. Make later user changes securely as root, preserve Authelia ownership/mode `0600`, and replace the file atomically. Authelia watches it. Keep a consistent backup; the seed is not a current user database.

| Account | Admission groups |
| --- | --- |
| hieronim | media-admin, infra-admin, household, finance |
| sarcia | household, finance |

SMTP uses Brevo with STARTTLS and certificate verification. Its startup check is disabled so a relay outage does not prevent enrolled users from signing in. For an explicitly approved credential replacement, use the hidden Clan prompt, not a shell argument:

```sh
CLAN_NO_COMMIT=1 nix develop --command clan vars generate server-legion --generator authelia-smtp --no-regenerate
```

The wildcard certificate covers `pieczarkowo.me` and `*.pieczarkowo.me`. The Cloudflare token needs Zone Read and DNS Edit for this zone only. Keep it in `cloudflare-dns/api-token`. `acme-renew-pieczarkowo.me.timer` handles renewal checks; manual issuance/renewal is a separate approved operation. Do not delete ACME state during a rollback.

Copyparty's `idp-h-key` is a secret header name, not a secret value. The paired runtime credentials must stay private. Caddy stages `/run/caddy/copyparty-idp.caddy` mode `0400` because reload commands cannot access its startup credential namespace. Keep that path readable only by Caddy inside its private runtime directory.

Forgejo LTS uses a small CLI patch to read its client secret from the environment during setup rather than argv. The daemon does not retain it. Its private `.authelia-source` fingerprint skips unchanged source updates so offline restarts do not require discovery. Do not manually edit that owned OAuth source.

Caddy's per-host access logs are disabled. Its structured error logger omits request URIs and request/response headers. This does not sanitize every native application message. Diagnose with selected non-sensitive fields; never paste raw Caddy/Jellyfin journals or callback URLs.

## DNS and public transport

Only `auth.pieczarkowo.me` uses Legion's Cloudflare Tunnel. The 17 application CNAMEs remain DNS-only and target `yze78b4.glddns.com`. The managed set has 18 records; mail, ACME and other undeclared records stay unmanaged. `ha.pieczarkowo.me` uses a tunnel managed outside this network. Do not adopt or change it.

The auth origin rejects non-LAN and router-masqueraded peers before handlers. Only loopback cloudflared may supply `CF-Connecting-IP`. cloudflared validates HTTPS to `127.0.0.1:443` with matching SNI/Host and a final 404. Do not replace these peer checks with trust in arbitrary forwarded headers.

From the repository root:

```sh
nix run .#legion-dns -- init -input=false
nix run .#legion-dns -- plan -out=review.tfplan
nix run .#legion-dns -- show review.tfplan
```

Review all additions, changes and deletions. Apply the exact saved plan only after separate approval:

```sh
nix run .#legion-dns -- apply review.tfplan
```

The wrapper passes Clan's token only in the provider environment. State and relative plans live under `$XDG_STATE_HOME/nixos-config/legion-dns/operator`, defaulting to `~/.local/state/nixos-config/legion-dns/operator`. Keep the directory mode `0700`, files `0600`, outside Git and the Nix store. Preserve the existing adopted state. Applying a saved plan does not ask again and can fail after partial changes.

If state is lost, restore its private backup first. Otherwise use read-only Cloudflare inspection and import only exact declared records with `import 'cloudflare_dns_record.<service>' '<zone_id>/<record_id>'`. Do not delete/recreate DNS records or adopt unrelated ones. Restoring OpenTofu state does not undo DNS changes.

The router reserves `192.168.8.2` for Legion. Its dnsmasq rules are:

```text
address=/*.pieczarkowo.me/192.168.8.2
server=/*.pieczarkowo.me/
server=/_acme-challenge.pieczarkowo.me/#
server=/_domainkey.pieczarkowo.me/#
server=/_dmarc.pieczarkowo.me/#
server=/ha.pieczarkowo.me/#
```

The empty server rule prevents public CNAME answers overriding local routing. The `#` exceptions use the existing upstream, AdGuard Home at `127.0.0.1:3053`. The wildcard does not affect the apex. Clients must use router DNS; browser DoH can bypass it. Do not add IPv6 or new upstream exceptions without checking actual routing. Router/DNS changes require separate approval.

## Activation and recovery

Run `nix flake check` and `nix develop --command pre-commit run --all-files`. Review the build/configuration scope against the current system before an authorized deployment. Do not deploy unrelated working-tree changes.

Keep SSH-key recovery, a prior protected NixOS generation, recent verified backups and external DNS/router state. See `backup-restore.md` for recovery commands and exclusions. Beszel is excluded from ongoing Borg; its cutover snapshots are local only. Isolated extraction and database checks are not a full disaster-recovery rehearsal. Restoring old state can revive revoked sessions.

A NixOS rollback does not undo account links, budget ownership, DNS changes or filesystem renames. Never restore databases automatically during activation. Actual and Copyparty guards own only their own chains. Preserve and verify each guard required by the target profile in both switch directions; never run blanket firewall cleanup.

Copyparty's canonical private directory is `/data/nas/sarcia`, mounted at `/nas/sarcia`. Keep the original `copyparty` generator and `sarka-password` filename/password. Default password-only Basic ignores the supplied username; `--usernames` would be a separate compatibility change. Hieronim/shared paths remain unchanged. A rollback to a pre-rename profile requires stopping Copyparty, checking that the destination is absent, and renaming before activating old tmpfiles rules. Both `storage.nix` and generated Copyparty tmpfiles settings must agree. Never delete an unexpected destination or overwrite newer state.

Enable-Actual uses host networking and a loopback-only UI. Keep its saved Actual URL, existing credentials and `PUBLIC_URL=https://actual-sync.pieczarkowo.me`. The pinned image ignores `ACTUAL_URL`. Change a saved target only through its supported settings/API; URL-specific caches and old credentials must not overwrite newer state. Do not apply host networking to other containers as a general workaround. NIXOS-0025 awaits the natural post-cutover banking result; do not force an import as a test.

After networking changes, check DNS in each application's actual mount and network namespaces. `ip netns exec wg` supplies a different resolver view and can hide a missing mount. NIXOS-0020 and NIXOS-0021 separately track the VPN and scheduled-backup DNS faults. Do not change credentials, endpoints or global DNS speculatively.
