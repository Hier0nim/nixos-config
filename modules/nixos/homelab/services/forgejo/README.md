# Forgejo and native Actions runner

Forgejo runs on the host. Its single Actions runner is the standard NixOS `services.gitea-actions-runner.instances.global` service, using `pkgs.forgejo-runner` with the `nix:host` label, capacity 1, and a three-hour job timeout. It executes directly on `server-legion`; Docker and other container-runner options are inapplicable and intentionally absent.

The runner has a dedicated unprivileged `gitea-runner` account and persistent state below `/var/lib/gitea-runner`, including writable checkout/work and internal Actions-cache roots at `/var/lib/gitea-runner/global/work` and `/var/lib/gitea-runner/global/actions-cache`. Its token remains SOPS-encrypted in `secrets/server-legion/forgejo-runner.yaml`; a runner-owned `TOKEN=<value>` environment file is rendered from it, and its update restarts `gitea-runner-global.service`. The account is not trusted by Nix and has no sudo, Docker, or Podman access. No runner environment variables are configured. Logging, polling, and TLS use upstream defaults.

Host jobs receive Bash, coreutils, Git, curl, Node.js 24, Nix, and zstd on their explicit PATH. They use the normal host Nix daemon and shared multi-user `/nix/store`, with Nix sandboxing enabled and sandbox fallback disabled. This is not a confidentiality boundary—store paths, build timing, and cache hits can be visible to jobs. Nix derivations must never embed secrets because derivation inputs and store paths can be exposed. The existing weekly GC deletes paths unreferenced for 14 days, preserving unreferenced outputs short-term. Do not enable global `keep-outputs`: CI has no arbitrary roots and doing so would grow disk use.

The runner service is hardened with a static runner user, private temporary and device namespaces, read-only system paths except its state directory, no capabilities, no new privileges, and no access to `/var/lib/homelab`. These restrictions reduce accidental host access but do not make untrusted code safe: do not run untrusted pull requests, mutually distrusting repositories, or workflows with deployment credentials on this host runner. Pin `uses:` actions to immutable revisions and review every host workflow carefully.

Forgejo's internal Actions cache is enabled for trusted workflow-keyed npm/NuGet download caches. It is distinct from the host Nix store and the signed `devenv.cachix.org` Nix binary cache; never cache `/nix/store` with Actions cache. It does not make immutable `/nix/store` sources writable or fix the affected devenv issue. Register the token in the Forgejo UI with the smallest appropriate (global or repository) runner scope, then deploy. The pinned upstream runner re-registers when registration state is absent, labels differ, or the stored token hash differs. To rotate safely, create a replacement token at that scope, update the SOPS-encrypted secret without placing the token in plaintext, and deploy; the rendered token file restarts the service and the token-hash change causes re-registration. Confirm the new registration in Forgejo and the service log, then revoke the old token. Normal rotation needs no manual deletion of `.runner` or other runtime data. Remove the old VM runner registration in the Forgejo UI after migration to avoid scheduling jobs to it.

## Troubleshooting

The explicit checkout/work root is writable and persistent, but cannot make Nix store sources writable. Workflows must use `actions/checkout` and run from the local `$GITHUB_WORKSPACE` checkout; for affected flake devenv projects, use the project-compatible `nix develop --no-pure-eval` or current devenv guidance.

## Operations and scaling

Check the native service with `systemctl status gitea-runner-global.service` and `journalctl -u gitea-runner-global.service`. Scaling should start by raising capacity from 1 to 2 only after reviewing CPU, memory, disk contention, and trust; then add a separately scoped runner on a second host. Do not add shared binary caches or Harmonia merely to reduce downloads: they require separate trust, signing, and availability planning.

## Legacy cleanup (manual only)

The migration does not delete prior VM data. After the old runner is stopped, deregistered, and any required data has been backed up, an operator may manually inspect and remove these obsolete paths: `/var/lib/microvms/forgejo-runner-storage-global/` (`var.raw`, `nix-cache/nix-cache.raw`, `docker/docker.raw`, and `work/work.raw`), `/var/lib/forgejo-nix/volume`, `/var/lib/forgejo-runner-work`, and Docker volume `forgejo-nix`. Do not remove them automatically as part of deployment.
