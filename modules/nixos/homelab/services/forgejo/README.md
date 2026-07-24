# Declarative Forgejo and Actions runner

This directory defines Forgejo and its isolated direct-QEMU Actions runner. The authoritative files are `server.nix`, `actions.nix`, `runner-images.nix`, `runner-vm.nix`, and `runner-secrets.nix`.

## Runner boundary

Each runner is an isolated direct-QEMU MicroVM. It has no host shares, a dedicated TAP network, a private Forgejo proxy, and fail-closed host firewall rules. The guest can reach any public HTTPS destination through its egress proxy; there is no domain allowlist. The proxy accepts only the guest, only HTTPS `CONNECT` on port 443, and denies private/reserved destinations. Direct traffic, plain HTTP, other host services, and the Docker socket are not reachable.

The deployed global runner is deliberately small and single-purpose:

- 4 vCPUs;
- 9 GiB guest memory, with the QEMU service capped at 10 GiB including overhead;
- one concurrent job;
- four bounded ext4 volumes for runner state, Docker data, workspace, and the persistent Nix cache.

Runner state and the Nix cache persist. Docker data and the workspace are disposable and reset on a cold start. Images are digest-pinned or Nix-built, loaded from offline OCI archives, and verified before the runner accepts jobs. Jobs cannot use privileged containers, arbitrary volumes, host paths, or Docker access. They retain Docker's standard capability profile and `no-new-privileges` inside the isolated VM.

## Persistent Nix reuse

The guest mounts `nix-cache.raw` at `/var/lib/forgejo-nix`. Its otherwise-empty `/var/lib/forgejo-nix/volume` directory is exposed through Docker's native local bind volume:

```console
docker volume create --driver local --opt type=none --opt o=bind --opt device=/var/lib/forgejo-nix/volume forgejo-nix
```

The guest creates and verifies that volume after Docker starts. The cache image is 64 GiB, with Nix retaining 4 GiB of free space and collecting until 8 GiB is free. Every job receives exactly:

```console
--mount type=volume,src=forgejo-nix,dst=/nix
```

One canonical `forgejo-runner-nix` image serves every runner label. It combines the Node 20 Bookworm base required by Forgejo JavaScript actions and FHS-native tools with only Nix, Git, CA certificates, and minimal POSIX utilities. It carries the normal `/nix/store` configuration, an explicit empty `build-users-group` for direct job Nix, proxy variables inherited by direct Nix builders, the cache.nixos substituter and key, 4/8 GiB `min-free`/`max-free` watermarks, a post-build hook that removes the unsandboxed builder's `/homeless-shelter` between derivations, and `sandbox = false` for local Docker jobs. Application services and toolchains—including PostgreSQL, Mailpit, Devenv, Chromium, Rust, and a second Node runtime—are deliberately not embedded. There is no guest Nix daemon, socket, remote setting, custom store URL, cache service, pressure timer, cache-path bind mount, or boot-store copy.

The runner's `nixSeedEpoch` must match every selected image. A populated cache volume with another epoch, or unexpected legacy contents without an epoch, fails startup. Increment the runner and image epoch only for a seed change that makes the existing `/nix` layout incompatible, then perform the owner reset below; removal of an unused seed utility is compatible and does not reset cached paths.

Nix's native `min-free`/`max-free` behavior bounds local-store collection. The filesystem remains fixed-size and the cache is shared by jobs on that runner, so path names, cache hits, timing, and capacity are not repository-confidential. Forgejo's Actions cache backend is intentionally disabled; `actions/cache` is therefore unsupported on this runner and should not be used as a second cache layer.

A project that pins a new Nixpkgs revision can request a derivation that is not yet available from a configured binary cache. Nix then builds it locally once; large SDK bootstrap builds can take a long time. Do not restart a running build to speed it up. Successful outputs stay in the persistent 64 GiB cache and are reused by later jobs.

## Owner migration and reset

The declared cache is now 64 GiB, while an older installation may still have a 12 GiB `nix-cache.raw`. Deployment does not resize that file automatically. The storage service arms a migration interlock and the VM remains blocked until the owner performs the cache-only migration.

Stop and runtime-mask the VM before deploying the cache change. The migration is destructive only to the persistent Nix cache; it does not touch runner state, Docker data, workspace, or Forgejo state.

```console
cd /home/hieronim/Projects/nixos-config
sudo systemctl mask --runtime --now microvm@forgejo-runner.service
nh os switch .#server-legion
sudo systemctl is-enabled microvm@forgejo-runner.service
sudo systemctl is-active microvm@forgejo-runner.service
sudo systemctl start forgejo-runner-nix-cache-migrate-global.service
sudo journalctl -u forgejo-runner-nix-cache-migrate-global.service --since today --no-pager
sudo stat -c '%n %s bytes' /var/lib/microvms/forgejo-runner-storage-global/nix-cache/nix-cache.raw
sudo blkid /var/lib/microvms/forgejo-runner-storage-global/nix-cache/nix-cache.raw
```

The migration service refuses to run unless the VM remains `masked`/`masked-runtime` and `inactive`, the cache is unmounted and unattached, and the old image is smaller than the declared size. It temporarily retires the old image, creates and validates a fresh 64 GiB ext4 image, then removes the retired cache only after validation succeeds. A failed migration leaves the interlock armed and never changes `var.raw`.

For a cache reset after a future seed epoch change, when the image already has the declared size, use the separate owner-only reset service instead:

```console
sudo systemctl start forgejo-runner-nix-cache-reset-global.service
sudo journalctl -u forgejo-runner-nix-cache-reset-global.service --since today --no-pager
```

After either successful operation, boot the VM:

```console
sudo systemctl unmask --runtime microvm@forgejo-runner.service
sudo systemctl start microvm@forgejo-runner.service
sudo journalctl -u microvm@forgejo-runner.service --since today --no-pager
```

Run two Nix jobs on the same runner, reboot the VM, and run the jobs again. Confirm the second run reuses the persistent `/nix` volume, while workspace and Docker data remain disposable.

## Validation

Use non-activating checks:

```console
nix flake check
pre-commit run --all-files
```

For a running guest, use read-only checks such as:

```console
findmnt -no SOURCE,FSTYPE,OPTIONS /var/lib/forgejo-nix
df -h /var/lib/forgejo-nix
docker volume inspect forgejo-nix
docker volume ls
systemctl status docker.service forgejo-runner-nix-volume-global.service gitea-runner-global.service
```

Pin every workflow `uses:` reference to an immutable commit SHA. Keep deployment credentials and mutually distrusting repositories on separate runners.

## Docker job diagnostics

The guest-root Docker observer records job and service-container lifecycle, network endpoints and aliases, selected `forgejo-nix` mount metadata, and Docker capability metadata. Jobs use Docker's standard default capability profile and retain each image's own `PATH` inside the isolated VM; they never receive Docker access or record environment values or container logs. During an active job, inspect it from the host with:

```console
sudo journalctl -fu microvm@forgejo-runner.service -o cat | grep --line-buffered 'Docker observer:'

Squid logs only failed egress transactions, recording the timestamp, guest address, `CONNECT` target, and HTTP status—never headers, bodies, successful destinations, or environment values. For repeated package-fetch failures, inspect:

```console
sudo journalctl -u forgejo-runner-egress-global.service --since '30 minutes ago' --no-pager
```

```
