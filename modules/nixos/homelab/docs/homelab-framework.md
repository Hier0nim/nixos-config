# Homelab Framework

This document describes the NixOS homelab framework -- how it is structured,
how services are configured, and how to add or modify components.

## Overview

The homelab framework manages self-hosted services on a NixOS server. It
provides:

- Declarative service configuration with sensible defaults
- Automatic permission management (see [permission-framework.md](permission-framework.md))
- Reverse proxy with authentication
- Backup management
- Hardware acceleration support
- Profile-based service stacks

## Directory Structure

```
modules/nixos/homelab/
  default.nix          # Module entry point
  options.nix          # All homelab options (services, auth, backup, etc.)
  meta-data.nix        # Shared metadata (proxied services, nixflix services)

  core/
    default.nix        # Imports all core modules
    permissions.nix    # Generates users, groups, systemd integration
    storage.nix        # Shared storage management (/data/*)
    state.nix          # Private state management (/var/lib/*)
    caddy.nix          # Reverse proxy configuration
    ssh.nix            # SSH key management

  services/
    default.nix        # Imports all service modules
    nixflix.nix        # Media stack (sonarr, radarr, jellyfin, etc.)
    immich.nix         # Photo management
    tdarr.nix          # Media transcoding
    copyparty.nix      # File sharing
    cockpit.nix        # Server management UI
    actual.nix         # Budget management
    enable-actual.nix  # Actual sync server
    backup.nix         # Restic backup system

  profiles/
    default.nix        # Imports all profiles
    media-stack.nix    # Media services profile
    photos-stack.nix   # Photo services profile
    files-stack.nix    # File services profile
    admin-stack.nix    # Admin services profile
```

## Enabling the Homelab

In your host configuration:

```nix
homelab = {
  enable = true;
  domain = "example.com";
  proxy.enable = true;

  profiles = {
    media.enable = true;
    photos.enable = true;
    files.enable = true;
    admin.enable = true;
  };

  services = {
    # Service-specific overrides
    jellyfin.hardwareAcceleration = {
      enable = true;
      type = "nvenc";
      device = "/dev/nvidia0";
    };
  };

  backup.enable = true;
};
```

## Profiles

Profiles are bundles of related services. Enable a profile to get a working
stack with minimal configuration.

### Media Stack (`profiles.media.enable`)

Enables: sonarr, sonarr-anime, radarr, prowlarr, jellyfin, audiobookshelf,
seerr (jellyseerr), recyclarr, qbittorrent

This is the full media stack. Sonarr and Radarr manage TV and movies. Prowlarr
manages indexers and is also used for manual audiobook discovery. qBittorrent
handles downloads. Jellyfin is the video media server. Audiobookshelf is the
audiobook library/player. Seerr handles user requests for video content. See
[audiobook-flow.md](audiobook-flow.md) for the curated audiobook workflow.

### Photos Stack (`profiles.photos.enable`)

Enables: immich

Immich is a self-hosted photo and video backup solution with mobile apps.

### Files Stack (`profiles.files.enable`)

Enables: copyparty

Copyparty is a file server with a web UI, supporting multiple users and
per-directory access control.

### Admin Stack (`profiles.admin.enable`)

Enables: cockpit

Cockpit is a web-based server management interface for monitoring and
administering the system.

## Service Configuration

### Common Options

Every service under `homelab.services.<name>` has these options:

```nix
homelab.services.myservice = {
  enable = true;                    # Enable the service
  user = "myservice";               # Runtime user
  group = "myservice";              # Runtime group
  expose.enable = true;             # Expose via reverse proxy
  expose.subdomain = "myservice";   # Subdomain for web access
  upstream.port = 8080;             # Local port
  auth.group = "media-admin";       # Auth group for proxy auth
  backup.enable = true;             # Include in backups
};
```

### Hardware Acceleration

Services that support GPU acceleration (jellyfin, immich, tdarr) have
additional options:

```nix
homelab.services.jellyfin.hardwareAcceleration = {
  enable = true;
  type = "nvenc";       # nvenc, vaapi, qsv, etc.
  device = "/dev/nvidia0";
};
```

### Reverse Proxy

Services are exposed through Caddy reverse proxy. The proxy handles:

- TLS certificates (automatic via ACME)
- Basic authentication (configurable per service)
- Path prefix routing (for services like qBittorrent)
- API auth bypass (for services with their own auth)

Authentication groups are defined in `homelab.auth.groups`:

```nix
homelab.auth.groups = {
  media-admin = {
    type = "basic";
    secretRef = "media_admin_basic_auth";
  };
  infra-admin = {
    type = "basic";
    secretRef = "infra_admin_basic_auth";
  };
};
```

### Backups

Services register backup paths through `homelab.services.<name>.backup`:

```nix
homelab.services.immich.backup = {
  enable = true;
  paths = [
    "/data/photos/library"
    "/data/photos/backups"
  ];
  exclude = [
    "/data/photos/upload"
    "/data/photos/thumbs"
  ];
};
```

The backup system uses restic and stores to a router SMB share. Backups run
nightly and are checked weekly.

## Storage Layout

### Shared Data (`/data`)

```
/data/
  media/
    movies/
    tv/
    anime/
    audiobooks/
    books/
  downloads/
    torrent/
      audiobooks/
    review/
      audiobooks/
  photos/
    library/
    backups/
    upload/
    thumbs/
    encoded-video/
  nas/
    shared/
    hieronim/
    sarka/
```

### Service State (`/var/lib`)

```
/var/lib/
  homelab/
    nixflix/
      sonarr/
      radarr/
      prowlarr/
      jellyfin/
      ...
    tdarr/
      server/
      configs/
      logs/
      cache/
    immich-hot/
      upload/
      thumbs/
      encoded-video/
      profile/
    enable-actual/
  actual/
  immich/
```

## Adding a New Service

See [permission-framework.md](permission-framework.md#adding-a-new-service)
for the permission integration steps.

Beyond permissions, you also need:

1. **Service configuration** -- the actual NixOS service module
2. **Proxy configuration** -- if the service has a web UI
3. **Backup configuration** -- if the service has persistent data
4. **Profile assignment** -- which stack does it belong to

## Nixflix (Media Stack)

The media stack uses the `nixflix` NixOS module for managing arr services and
Jellyfin. The homelab framework integrates with nixflix through an adapter in
`services/nixflix.nix` that translates nixflix service configurations into
`homelab.apps` registrations.

Services managed by nixflix:

- sonarr, sonarr-anime (TV)
- radarr (movies)
- prowlarr (indexers)
- jellyfin (media server)
- seerr/jellyseerr (requests)
- recyclarr (quality profiles)
- qbittorrent (downloads)

Audiobooks are intentionally handled as a curated lane instead of Readarr-style
automation. Prowlarr can search authorized audiobook indexers and qBittorrent
downloads into the `audiobooks` category, but final import into Audiobookshelf
is a reviewed `audiobook-import` step. See [audiobook-flow.md](audiobook-flow.md).

The nixflix adapter automatically:

- Creates app registrations for each enabled service
- Sets up storage access based on service needs
- Configures VPN for torrent and indexer services
- Manages secrets through SOPS

## Immich (Photo Stack)

Immich requires special handling because of its SSD-backed hot storage:

- Hot data (uploads, thumbnails, encoded videos) lives on fast SSD storage
  under `/var/lib/homelab/immich-hot`
- This is bind-mounted into `/data/photos/` for the shared photo library
- `.immich` marker files are managed by the framework to ensure correct
  ownership

The bind mount setup:

```nix
fileSystems."/data/photos/upload" = {
  device = "/var/lib/homelab/immich-hot/upload";
  fsType = "none";
  options = [ "bind" ];
};
# ... same for thumbs, encoded-video, profile
```

## Tdarr (Media Transcoding)

Tdarr runs as a Docker container with access to the media library. It uses:

- GPU passthrough for hardware transcoding
- Bind-mounted media and state directories
- Environment variables for PUID/PGID configuration

## Secrets Management

Secrets are managed through SOPS (Secrets OPerationS). Each service's secrets
are stored in a YAML file under `secrets/<hostname>/`:

```
secrets/server-legion/
  media.yaml          # Media service API keys and passwords
  caddy.yaml          # Proxy auth credentials
  copyparty.yaml      # Copyparty user passwords
  backup.yaml         # Backup repository credentials
  vpn/
    qbittorrent-wireguard.conf  # VPN config
```

## Networking

- All services bind to `127.0.0.1` (not exposed directly)
- Caddy reverse proxy handles external access on ports 80/443
- qBittorrent uses a WireGuard VPN for external traffic
- Flaresolverr (for prowlarr) runs in the VPN namespace

## Validation

Before applying changes:

```bash
# Format all nix files
nixfmt modules/nixos/homelab/**/*.nix

# Check for trailing whitespace
git diff --check

# Evaluate the full system config
nix eval .#nixosConfigurations.server-legion.config.system.build.toplevel.drvPath
```

After applying:

```bash
# Check for failed services
systemctl --failed

# Check specific service logs
journalctl -u <service-name> -n 120 --no-pager

# Check backup status
systemctl status restic-backups-homelab
```

## Current Service Registry

| Service | Subdomain | Port | Auth | Profile |
|---------|-----------|------|------|---------|
| jellyfin | grzybflix | 8096 | - | media |
| sonarr | sonarr | 8989 | media-admin | media |
| sonarr-anime | sonarr-anime | 8990 | media-admin | media |
| radarr | radarr | 7878 | media-admin | media |
| prowlarr | indexers | 9696 | media-admin | media |
| seerr | chciejnik | 5055 | - | media |
| qbittorrent | pobieralnia | 8080 | media-admin | media |
| tdarr | tdarr | 8265 | media-admin | media |
| immich | fotki | 2283 | - | photos |
| copyparty | pliki | 3923 | - | files |
| cockpit | admin | 9090 | infra-admin | admin |
| actual | kasa | 3100 | - | - |
| enable-actual | actual-sync | 3000 | infra-admin | - |

## Anti-Patterns

Things to avoid:

1. **Per-service ExecStartPre with chown/chmod** -- use the app registry instead
2. **Recursive tmpfiles Z on broad roots** -- only repair declared paths
3. **Hardcoded consumer lists** -- discover from app registrations
4. **Running containers as root** -- use dedicated UIDs
5. **Backing up ephemeral data** -- exclude upload, thumbs, encoded-video
6. **Exposing services directly** -- always use the reverse proxy
