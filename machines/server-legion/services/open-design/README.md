# OpenDesign on Legion

Hieronim and Sarcia share one OpenDesign instance and Pi profile. Caddy and
Authelia protect `design.pieczarkowo.me` for the `household` group. There are no
separate OpenDesign accounts. Projects, provider credentials and agent access
are shared. The service is disabled until `services.open-design.enable = true`
is set in Legion's configuration. Builds do not activate it or change DNS.

## Build and test

`image-lock.json` pins OpenDesign `open-design-v0.27.0` at commit
`77b8eb889cf8a27a50d3325029d1b3bee5da0910`. Upstream still reports package version
`0.25.1`. The runtime pins Pi `1.5.0` and agent-browser `0.41.2`. Nix supplies
Node, Chromium and fonts, and records their versions in the image.

```sh
roots="$HOME/.local/state/open-design"
mkdir -p "$roots"
nix build .#open-design-image --out-link "$roots/image-candidate"
nix build .#open-design-image.copyToDockerDaemon --out-link "$roots/loader-candidate"
nix run .#open-design-smoke -- podman
nix flake check
nix develop --command pre-commit run --all-files
```

The smoke test uses rootless Podman with disposable state and no external
networking. It checks the web UI, concurrent browsers, cleanup and state after
container recreation. It does not call a model. On a Docker host, build
`.#open-design-smoke` and run its executable through sudo with argument `docker`.

The image has a content-derived local tag. Keep the output symlinks as Nix GC
roots, along with the matching Git revision and lockfiles. Keep the last working
image and loader separately until the candidate passes your checks. A registry
is not needed. The service loads built layers into Docker and never builds,
installs packages or pulls an image at startup.

## Start and log in

Before enabling the service, recheck that UID/GID 1004 and port 7456 are free.
Review the enabled NixOS configuration, then deploy through the existing Clan
workflow after approval. Follow [ingress operations](../../ingress-operations.md)
to inspect the DNS plan. DNS apply needs separate approval.

```sh
ssh -t homelab 'sudo open-design-pi'
```

Use Pi's `/login` menu, then `/model`. Complete any browser or code flow in the
terminal, never in chat. This Pi profile is separate from desktop Pi. Start with
the intended subscription if the menu supports it. Do not copy laptop tokens or
deploy OAuth files through Clan Vars.

Choose Local Agent / Pi and the model in OpenDesign. Startup adds the Linux
browser policy without changing those choices, Pi settings or credentials.
It leaves Pi's standard tools and prompt in place. The adapter waits for
`agent_settled` because Pi 1.5 can still recover after `agent_end`. OpenDesign's
OD Next strategy rejects visual-check instructions, so this deployment selects
the supported slim route with `OD_NEXT_STRATEGY_ROLLOUT=off`. Recheck both choices
when updating.

## Run it

All persistent data lives in `/var/lib/open-design`, mounted at `/state`.
Pi's home is `/state/runtime/pi-home`. The host directory belongs to UID/GID
1004 and has mode 0700. Browser profiles and caches live in temporary storage.
The root filesystem is read-only. Mounts and resource limits are in `default.nix`.

Only host loopback port 7456 is published. A local firewall chain admits root
and Caddy, including calls through Docker's bridge. The module requires Legion's
IPv4 `docker0` bridge. After deployment, test both loopback and the container IP
as an unrelated host user, then check SSO denial and LAN/WAN access.

Agent commands can read this instance's credentials and reach its network,
including reachable LAN services. Chromium uses `--no-sandbox`; the container
is the boundary. Do not mount host homes, credentials or the Docker socket.
The launcher gives each Pi run its own browser session and loopback CDP port.
The browser skill explains how to use it.

```sh
ssh homelab 'sudo open-design-pi --list-models'
ssh homelab 'sudo open-design-doctor'
ssh homelab 'sudo open-design-doctor --browser'
```

Doctor checks versions, private state, the web UI, policy and model discovery.
`--browser` also checks concurrent Chromium sessions, screenshots and cleanup.
Neither command tests a subscription or makes a model request. Test a real task
after login, including screenshot inspection, correction, continuation and
cancellation. Exports and native browser UI actions need their own tests.

Docker keeps two 4 MiB log files. Read `sudo docker logs --tail 100 open-design`
on the host. Do not share raw logs, cookies, callback URLs or credential files.

## Restore or update

Snapshots stop the container, so they interrupt generation. They save projects,
databases, Pi sessions and credentials, but not temporary browser profiles.
Follow [backup restore](../../backup-restore.md). Test a restored copy with its
matching image on another loopback port before replacing live state. Keep the
rollback copy. Old OAuth tokens may need a fresh login.

Before an update, save a snapshot and retain the working image. Build and smoke
test the candidate first. A database migration may require restoring the
matching snapshot when rolling back. Keep newer projects before doing so.
