# Homelab Framework Architecture

This document describes how homelab service modules register permissions, state,
and shared storage access. Its purpose is to make future changes easy to review
and to avoid permission drift or one-off service fixes.

## Core Principle

Each service module owns its app registration:

```nix
homelab.apps.myapp = {
  enable = true;
  user = "myapp";
  group = "myapp";
  serviceNames = [ "myapp" ];
  storageAccess = [ "media" ];
  state.paths = [ "/var/lib/homelab/myapp" ];
};
```

Core modules consume `homelab.apps` and generate the system integration:

- Unix users and groups.
- Systemd `SupplementaryGroups`.
- Explicit service umask policy: `0002` for shared writers and `0022` otherwise.
- Shared storage tmpfiles and repair units.
- Private state tmpfiles and repair units.
- Systemd ordering so services wait for their guardrails.

Service modules should not add ad hoc `chown`, `chmod`, or storage dependency
hooks unless the requirement cannot be represented in `homelab.apps`.

## Data Domains

The framework intentionally separates shared data from private app state.

### Shared Storage

Shared storage lives under `/data`.

Examples:

- `/data/media`
- `/data/downloads`
- `/data/photos`
- `/data/nas`

Shared storage is group-owned and uses setgid directory modes. Repair is
non-recursive by default. The framework repairs only declared tree roots and
declared top-level subdirectories. This avoids expensive full-library chmod/chown
operations and avoids mutating user media files unnecessarily.

Apps opt in with:

```nix
storageAccess = [ "media" "downloads" ];
```

The role-to-group mapping is:

| Role | Unix group |
| --- | --- |
| `media` | `media` |
| `downloads` | `media` |
| `photos` | `photos` |
| `nas` | `nas` |

### Private State

Private app state lives under `/var/lib`, `/var/cache`, or a service-specific
state path.

Examples:

- `/var/lib/homelab/nixflix/jellyfin`
- `/var/cache/jellyfin`
- `/var/lib/homelab/immich-hot`

Private state is owned by the app user and group. Repair is recursive because
all files below those paths should belong to the app.

Apps opt in with:

```nix
state.paths = [
  "/var/lib/homelab/myapp"
  "/var/cache/myapp"
];
```

## Core Modules

### `options.nix`

Defines the `homelab.apps` contract.

Important fields:

- `enable`: include the app in generated integration.
- `user` / `group`: runtime identity.
- `manageUser`: create the system user and primary group.
- `serviceNames`: systemd service units that must wait for generated guardrails.
- `storageAccess`: shared storage roles consumed by the app.
- `supplementaryGroups`: additional groups such as `render` or `video`.
- `sharedWriter`: apply `UMask=0002` to app units.
- `state.paths`: recursively app-owned private state paths.
- `state.mode`: mode applied to private state directories.
- `state.managedFiles`: exact app-owned files normalized before startup.

### `core/permissions.nix`

Consumes enabled `homelab.apps` and generates:

- Shared role groups: `media`, `photos`, `nas`.
- App users and primary groups when `manageUser = true`.
- User-level `extraGroups`.
- Service-level `SupplementaryGroups`.
- Explicit service `UMask`: `0002` for shared writers, `0022` otherwise.

Service-level `SupplementaryGroups` are generated even when user-level groups
also exist. This makes the actual systemd service sandbox explicit and avoids
depending only on account database membership.

### `core/storage.nix`

Defines shared storage trees and discovers consumers from app registrations.

Generated units:

- `homelab-storage-media.service`
- `homelab-storage-downloads.service`
- `homelab-storage-photos.service`
- `homelab-storage-nas.service`

Each consumer service gets:

```nix
after = [ "homelab-storage-<role>.service" ];
requires = [ "homelab-storage-<role>.service" ];
```

The storage repair script clears ACLs, sets owner/group, and applies the declared
mode only on tree roots and declared subdirectories.

### `core/state.nix`

Discovers apps with non-empty `state.paths`.

Generated units:

- `homelab-state-<app>.service`

Each app service gets:

```nix
after = [ "homelab-state-<app>.service" ];
requires = [ "homelab-state-<app>.service" ];
```

State repair is recursive:

- `chown -R <user>:<group>`
- `chmod -R u+rwX`

Nested state paths are collapsed to their top-level roots before recursive
repair, avoiding repeated traversal of the same tree. This is intentional for
private app state and must not be used for shared media libraries.

`state.managedFiles` handles exact files that an app must be able to update,
including files located inside shared storage. The framework creates missing
files and repairs only their owner and mode; it does not recursively change the
surrounding shared tree.

## Current App Registrations

### Nixflix Apps

Registered in `modules/nixos/homelab/services/nixflix.nix`.

Apps:

- `prowlarr`
- `qbittorrent`
- `radarr`
- `recyclarr`
- `seerr`
- `sonarr`
- `sonarr-anime`
- `jellyfin`

Nixflix-managed services set `manageUser = true` because the framework controls
their systemd identity.

`qbittorrent`, `radarr`, `sonarr`, and `sonarr-anime` consume both `media` and
`downloads`.

`jellyfin` consumes `media` and declares all Jellyfin private state paths,
including cache and metadata.

### Immich

Registered in `modules/nixos/homelab/services/immich.nix`.

Consumes `photos` and declares SSD-backed hot state paths under
`/var/lib/homelab/immich-hot`.

The hot state directories are bind-mounted into `/data/photos`.
Immich's `.immich` integrity markers are exact managed files. Markers for
bind-mounted directories are managed at their backing paths so ordering does
not depend on whether the bind mount is already active.

### Tdarr

Registered in `modules/nixos/homelab/services/tdarr.nix`.

Consumes `media` and uses service name `docker-tdarr`, because the OCI container
unit is not named `tdarr.service`.

### Copyparty

Registered in `modules/nixos/homelab/services/copyparty.nix`.

Consumes `nas`.

## Service Ordering Rules

Use `homelab.apps.<name>.serviceNames` for runtime units that need storage and
state guardrails.

Use explicit systemd dependencies only for orchestration units that depend on
multiple apps or APIs.

Example:

`seerr-jellyfin.service` configures Seerr using the Jellyfin API. It is not a
runtime app. It must explicitly wait for both:

- `seerr.service`
- `jellyfin.service`

## Validation Checklist

Run these before applying framework changes:

```bash
nixfmt modules/nixos/homelab/**/*.nix
git diff --check
nix eval .#nixosConfigurations.server-legion.config.system.build.toplevel.drvPath
```

Inspect app registrations:

```bash
nix eval --json .#nixosConfigurations.server-legion.config.homelab.apps
```

Check representative dependencies:

```bash
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.immich-server.requires
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.jellyfin.requires
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.qbittorrent.requires
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.\"docker-tdarr\".requires
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.\"seerr-jellyfin\".requires
```

Check generated service groups:

```bash
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.jellyfin.serviceConfig.SupplementaryGroups
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.immich-server.serviceConfig.SupplementaryGroups
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.qbittorrent.serviceConfig.SupplementaryGroups
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.\"docker-tdarr\".serviceConfig.SupplementaryGroups
```

Check repair unit path coverage:

```bash
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.\"homelab-storage-media\".unitConfig.RequiresMountsFor
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.\"homelab-storage-photos\".unitConfig.RequiresMountsFor
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.\"homelab-state-jellyfin\".unitConfig.RequiresMountsFor
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.\"homelab-state-immich\".unitConfig.RequiresMountsFor
```

After switching, inspect failures:

```bash
systemctl --failed
journalctl -u <unit> -n 120 --no-pager
```

## Anti-Patterns

Avoid:

- Per-service `ExecStartPre = chown -R ...`.
- Recursive tmpfiles `Z` on broad roots like `/data` or `/var/lib/homelab`.
- Hardcoded storage consumer lists in `core/storage.nix`.
- Hardcoded user group lists in `core/permissions.nix`.
- Registering dependencies on the wrong unit name, for example `tdarr.service`
  when the real unit is `docker-tdarr.service`.
- Using shared storage repair for private app state, or private state repair for
  shared media libraries.

## When Adding a New App

1. Add normal service configuration.
2. Add `homelab.apps.<name>` in the same service module.
3. Set `serviceNames` to the actual systemd unit names.
4. Add `storageAccess` only for shared trees the service reads or writes.
5. Add `state.paths` only for private app-owned paths.
6. Set `sharedWriter = true` only when the service writes group-shared files.
7. Run the validation checklist.

## Security

### Symlink Protection

All repair scripts in `core/storage.nix` and `core/state.nix` refuse to follow
symlinks. Before operating on a path, the script checks `if [ -L "$path" ]`
and exits with an error if true.

This prevents a symlink attack where a compromised service replaces a managed
directory with a symlink to a sensitive system path (like `/etc`). Without this
check, the root repair service would follow the symlink and change ownership
of the target.

### Path Validation

The framework validates all declared paths at Nix evaluation time:

- Paths under system directories (`/etc`, `/usr`, `/bin`, `/dev`, `/proc`,
  `/sys`, `/run`, `/nix`) are rejected.
- All paths must be absolute.
- The root path `/` is rejected.

These assertions are in `core/permissions.nix` and run even when `cfg.enable`
is false (they pass trivially since no apps are enabled).

### Container Security

Some containers (Tdarr, Enable Actual) run with elevated privileges:

- **Tdarr**: Uses `PUID=0` for media file access. This is a known tradeoff
  for compatibility with the Tdarr container image.
- **Enable Actual**: Runs with `--user=0:0` for data directory access.

Both should be migrated to non-root UIDs when the container images support it.

### PrivateUsers Tradeoff

Jellyfin and Immich disable `PrivateUsers` because they need real host
UID/GID semantics for shared storage. This removes user-namespace isolation
but is necessary for group-owned media directories.

Compensating controls:
- Tight `ReadWritePaths` on service units
- `ProtectSystem=strict` where possible
- `NoNewPrivileges=yes` on service units
- Non-writable parent directories for repair-managed paths
