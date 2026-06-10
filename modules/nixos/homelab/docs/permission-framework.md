# Permission Framework

This document explains how the homelab framework manages permissions, storage
access, and service state. The goal is to make permission behavior predictable
and to avoid the common problem where a service cannot write to its own
directories.

## Core Idea

Every homelab service declares its permission needs through a single
`homelab.apps.<name>` registration. Core modules read these registrations
and generate all system integration automatically:

- Unix users and groups
- Systemd service groups and umask
- Shared storage directories and repair units
- Private state directories and repair units
- Service startup ordering

Service modules should not add their own `chown`, `chmod`, or `ExecStartPre`
permission logic unless the requirement cannot be expressed through the app
registry.

## App Registration

Each service registers itself under `homelab.apps`:

```nix
homelab.apps.myapp = {
  enable = true;
  user = "myapp";
  group = "myapp";
  manageUser = true;
  serviceNames = [ "myapp" ];
  storageAccess = [ "media" "downloads" ];
  sharedWriter = true;
  state.paths = [
    "/var/lib/homelab/myapp"
    "/var/cache/myapp"
  ];
};
```

### Fields

| Field | Type | Purpose |
|-------|------|---------|
| `enable` | bool | Include this app in generated integration |
| `user` | string | Unix user that runs the service |
| `group` | string | Primary Unix group for the service |
| `manageUser` | bool | Create the user and group automatically |
| `serviceNames` | list of strings | Systemd service units that need guardrails |
| `storageAccess` | list of strings | Shared storage roles this app needs |
| `supplementaryGroups` | list of strings | Extra groups (e.g. `render`, `video`) |
| `sharedWriter` | bool | Use `UMask=0002` for group-writable files |
| `state.paths` | list of strings | Private directories owned by this app |
| `state.mode` | string | Mode for private state directories (default: `0750`) |
| `state.managedFiles` | list | Exact files the framework creates and owns |

## Two Types of Storage

The framework separates shared data from private app state. This is the most
important concept to understand.

### Shared Storage (under /data)

Shared storage is where media, photos, and documents live. Multiple services
need read or write access to the same directories.

Location: `/data/media`, `/data/downloads`, `/data/photos`, `/data/nas`

Properties:
- Group-owned by a role group (e.g. `media`, `photos`, `nas`)
- Uses setgid directories (`2775` or `2770`) so new files inherit the group
- Repair is non-recursive -- only the root and declared subdirectories get
  their permissions fixed
- Apps opt in with `storageAccess = [ "media" ]`

The framework does NOT recursively repair shared storage. This is intentional.
A media library with thousands of files should not have `chown -R` run on every
boot. Only the directory structure itself is repaired.

### Private State (under /var/lib)

Private state is where a service stores its database, config, and cache. Only
that service should access these paths.

Location: `/var/lib/homelab/<app>`, `/var/cache/<app>`, etc.

Properties:
- Owned by the app user and group
- Repair is recursive -- all files below belong to the app
- Apps declare with `state.paths = [ "/var/lib/homelab/myapp" ]`

## Role-to-Group Mapping

When an app declares `storageAccess`, the framework maps roles to Unix groups:

| Role | Unix group | Typical use |
|------|-----------|-------------|
| `media` | `media` | Movies, TV shows, anime, audiobooks |
| `downloads` | `media` | Torrent download directories |
| `photos` | `photos` | Photo library |
| `nas` | `nas` | Shared file storage |

Note: `media` and `downloads` share the same Unix group. This is because
downloaded files are imported into the media library, so they need the same
group ownership.

## What Gets Generated

### For every enabled app

1. **Unix user and group** (when `manageUser = true`)
2. **User extraGroups** from `storageAccess` and `supplementaryGroups`
3. **Service SupplementaryGroups** -- explicitly set on the systemd unit
4. **Service UMask** -- `0002` for shared writers, `0022` otherwise

### For shared storage

1. **tmpfiles rules** -- create directories with correct owner/group/mode
2. **Repair service** (`homelab-storage-<role>.service`) -- runs at boot
3. **Service ordering** -- consumer services wait for repair to complete

Example generated unit: `homelab-storage-media.service`

```ini
[Unit]
Description=Repair permissions for /data/media
RequiresMountsFor=/data/media
After=local-fs.target
Requires=local-fs.target
Before=jellyfin.service sonarr.service radarr.service ...

[Service]
Type=oneshot
ExecStart=/nix/store/.../homelab-media-repair-permissions
```

### For private state

1. **tmpfiles rules** -- create directories with correct owner/group/mode
2. **tmpfiles rules** -- create managed files with correct owner/group/mode
3. **Repair service** (`homelab-state-<app>.service`) -- runs at boot
4. **Service ordering** -- app services wait for repair to complete

Example generated unit: `homelab-state-jellyfin.service`

```ini
[Unit]
Description=Repair permissions for jellyfin state
RequiresMountsFor=/var/lib/homelab/nixflix/jellyfin
After=local-fs.target
Requires=local-fs.target
Before=jellyfin.service jellyfin-libraries.service

[Service]
Type=oneshot
ExecStart=/nix/store/.../homelab-jellyfin-repair-permissions
```

## Security

### Symlink Protection

All repair scripts refuse to follow symlinks. If a service is compromised and
replaces a managed directory with a symlink, the repair unit will fail rather
than modifying the symlink target. This prevents privilege escalation attacks
where a compromised service could trick the root repair into changing
ownership of system directories like `/etc`.

### Path Validation

The framework validates all declared paths at evaluation time. Paths under
system directories (`/etc`, `/usr`, `/bin`, `/dev`, `/proc`, `/sys`, `/run`,
`/nix`) are rejected. All paths must be absolute.

### PrivateUsers

Some services (Jellyfin, Immich) need `PrivateUsers=false` because they
require real host UID/GID semantics for shared storage. This is a conscious
security tradeoff documented in each service module.

## Adding a New Service

Follow these steps when adding a new homelab service:

### 1. Create the service module

Create `modules/nixos/homelab/services/myservice.nix`:

```nix
{ config, lib, ... }:
let
  cfg = config.homelab;
  myService = cfg.services.myservice;
in {
  config = lib.mkIf (cfg.enable && myService.enable) {
    # Register permissions with the framework
    homelab.apps.myservice = {
      enable = true;
      user = myService.user;
      group = myService.group;
      manageUser = true;
      serviceNames = [ "myservice" ];
      storageAccess = [ "media" ];  # only what you actually need
      sharedWriter = true;          # if writing to shared storage
      state.paths = [
        "/var/lib/homelab/myservice"
      ];
    };

    # Your actual service configuration
    services.myservice = {
      enable = true;
      # ...
    };
  };
}
```

### 2. Add service options

In `options.nix`, add your service to the `homelab.services` attrset:

```nix
myservice = mkServiceOptions {
  name = "myservice";
  subdomain = "myservice";
  port = 8080;
  dataGroups = [ "media" ];
};
```

### 3. Register in meta-data.nix

If your service needs a web proxy, add it to `proxiedServices`:

```nix
proxiedServices = [
  # ... existing services ...
  "myservice"
];
```

### 4. Add to a profile (optional)

If your service belongs to a stack, add it to the profile:

```nix
# profiles/media-stack.nix
homelab.services.myservice.enable = true;
```

### 5. Import the module

Add the import to `services/default.nix`:

```nix
imports = lib.flatten [
  # ... existing imports ...
  ./myservice.nix
];
```

### 6. Validate

```bash
# Check the config evaluates
nix eval .#nixosConfigurations.server-legion.config.system.build.toplevel.drvPath

# Inspect the app registration
nix eval --json .#nixosConfigurations.server-legion.config.homelab.apps

# Check service dependencies
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.myservice.requires

# Check service groups
nix eval --json .#nixosConfigurations.server-legion.config.systemd.services.myservice.serviceConfig.SupplementaryGroups
```

## Common Patterns

### Service that only reads shared storage

```nix
homelab.apps.jellyfin = {
  enable = true;
  user = "jellyfin";
  group = "jellyfin";
  serviceNames = [ "jellyfin" ];
  storageAccess = [ "media" ];
  # sharedWriter defaults to false -- read-only access
  state.paths = [ "/var/lib/jellyfin" ];
};
```

### Service that writes to shared storage

```nix
homelab.apps.sonarr = {
  enable = true;
  user = "sonarr";
  group = "sonarr";
  manageUser = true;
  serviceNames = [ "sonarr" ];
  storageAccess = [ "media" "downloads" ];
  sharedWriter = true;  # UMask=0002 so files are group-writable
  state.paths = [ "/var/lib/homelab/nixflix/sonarr" ];
};
```

### Service with GPU access

```nix
homelab.apps.immich = {
  enable = true;
  user = "immich";
  group = "immich";
  serviceNames = [ "immich-server" ];
  storageAccess = [ "photos" ];
  supplementaryGroups = [ "render" "video" ];
  state.paths = [ "/var/lib/homelab/immich-hot" ];
};
```

### Service with managed files in shared storage

Some services create marker files inside shared storage. The framework
creates and owns these files:

```nix
homelab.apps.immich = {
  # ... other fields ...
  state.managedFiles = [
    { path = "/data/photos/library/.immich"; }
    { path = "/data/photos/backups/.immich"; }
  ];
};
```

## Troubleshooting

### Service cannot write to its own directory

Check that the service is registered in `homelab.apps` with the correct
`user` and `group`. Verify the state path is listed in `state.paths`.

### Service cannot write to shared storage

Check that:
1. `storageAccess` includes the right role (e.g. `media`)
2. `sharedWriter = true` if writing group-owned files
3. The service user is in the correct group (check `extraGroups`)

### Permission repair fails at boot

Check `journalctl -u homelab-state-<app>.service` or
`journalctl -u homelab-storage-<role>.service` for error messages.

Common causes:
- Symlink detected where a directory is expected (service may have created it)
- Path does not exist and parent is not writable
- Disk not mounted (check `RequiresMountsFor`)

### Two services conflict on shared storage

If two services need write access to the same directory, both should declare
the same `storageAccess` role and both should set `sharedWriter = true`.
The setgid directory mode ensures new files inherit the correct group.
