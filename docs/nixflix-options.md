# nixflix Options Reference

All options available under the `nixflix.*` namespace. Sorted by service.

---

## Top-level options

| Option                        | Type       | Default         | Description                              |
| ----------------------------- | ---------- | --------------- | ---------------------------------------- |
| `nixflix.enable`              | bool       | false           | Enable nixflix                           |
| `nixflix.mediaDir`            | path       | /data/media     | Root media directory                     |
| `nixflix.downloadsDir`        | path       | /data/downloads | Downloads/import directory               |
| `nixflix.stateDir`            | path       | /var/lib        | State directory root                     |
| `nixflix.mediaUsers`          | listOf str | []              | Extra users added to the media group     |
| `nixflix.serviceDependencies` | listOf str | []              | Systemd services nixflix should wait for |

### Reverse proxy

| Option                          | Type       | Default   | Description                           |
| ------------------------------- | ---------- | --------- | ------------------------------------- |
| `nixflix.nginx.enable`          | bool       | false     | Enable nginx reverse proxy            |
| `nixflix.nginx.domain`          | str        | "nixflix" | Base domain for subdomain routing     |
| `nixflix.nginx.addHostsEntries` | bool       | false     | Add /etc/hosts entries for subdomains |
| `nixflix.nginx.forceSSL`        | bool       | false     | Force SSL redirect                    |
| `nixflix.nginx.enableACME`      | bool       | false     | Enable ACME in virtual hosts          |
| `nixflix.caddy.enable`          | bool       | false     | Enable Caddy reverse proxy            |
| `nixflix.caddy.domain`          | str        | —         | Base domain                           |
| `nixflix.caddy.addHostsEntries` | bool       | false     | Add /etc/hosts entries                |
| `nixflix.caddy.tls.enable`      | bool       | false     | Enable TLS                            |
| `nixflix.caddy.tls.acmeEmail`   | nullOr str | null      | ACME registration email               |
| `nixflix.caddy.tls.internal`    | bool       | false     | Use Caddy internal (self-signed) CA   |

### Theme

| Option                 | Type | Default     | Description                   |
| ---------------------- | ---- | ----------- | ----------------------------- |
| `nixflix.theme.enable` | bool | false       | Enable theming via theme.park |
| `nixflix.theme.name`   | str  | "overseerr" | theme.park theme name         |

### Read-only derived

| Option                                 | Type | Description                     |
| -------------------------------------- | ---- | ------------------------------- |
| `nixflix.reverseProxy.enable`          | bool | Whether any RP is enabled       |
| `nixflix.reverseProxy.domain`          | str  | Active RP domain                |
| `nixflix.reverseProxy.addHostsEntries` | bool | Whether hosts entries are added |
| `nixflix.reverseProxy.forceSSL`        | bool | Whether SSL is forced           |

---

## `nixflix.globals.*`

UIDs/GIDs for all nixflix services. Useful for shared permission setups.

| Option                       | Type | Description               |
| ---------------------------- | ---- | ------------------------- |
| `globals.libraryOwner.uid`   | int  | Shared library UID        |
| `globals.libraryOwner.gid`   | int  | Shared library GID        |
| `globals.libraryOwner.group` | str  | Shared library group name |
| `globals.<service>.uid`      | int  | Per-service UID           |
| `globals.<service>.gid`      | int  | Per-service GID           |

---

## `nixflix.jellyfin.*`

### Core

| Option                         | Type    | Default                    | Description                                |
| ------------------------------ | ------- | -------------------------- | ------------------------------------------ |
| `jellyfin.enable`              | bool    | false                      | Enable Jellyfin                            |
| `jellyfin.package`             | package | pkgs.jellyfin              | Jellyfin package                           |
| `jellyfin.apiKey`              | secret  | —                          | API key injected into the database         |
| `jellyfin.user`                | str     | "jellyfin"                 | Service user                               |
| `jellyfin.group`               | str     | globals.libraryOwner.group | Service group                              |
| `jellyfin.dataDir`             | path    | stateDir/jellyfin          | Data directory                             |
| `jellyfin.configDir`           | path    | dataDir/config             | Config directory                           |
| `jellyfin.cacheDir`            | path    | /var/cache/jellyfin        | Cache directory                            |
| `jellyfin.logDir`              | path    | dataDir/log                | Log directory                              |
| `jellyfin.openFirewall`        | bool    | false                      | Open ports 8096, 8920 TCP + 1900, 7359 UDP |
| `jellyfin.subdomain`           | str     | "jellyfin"                 | Reverse proxy subdomain                    |
| `jellyfin.reverseProxy.expose` | bool    | true                       | Expose via RP                              |
| `jellyfin.vpn.enable`          | bool    | false                      | Route traffic through VPN                  |
| `jellyfin.connectionAddress`   | str     | derived                    | Read-only connection address               |

### jellyfin.network

| Option                            | Type       | Default                 | Description                |
| --------------------------------- | ---------- | ----------------------- | -------------------------- |
| `network.autoDiscovery`           | bool       | true                    | Enable DLNA/auto-discovery |
| `network.baseUrl`                 | str        | ""                      | Base URL prefix            |
| `network.enableHttps`             | bool       | false                   | Enable HTTPS               |
| `network.enableIPv4`              | bool       | true                    | Enable IPv4                |
| `network.enableIPv6`              | bool       | false                   | Enable IPv6                |
| `network.enableRemoteAccess`      | bool       | true                    | Enable remote access       |
| `network.enableUPnP`              | bool       | false                   | Enable UPnP port mapping   |
| `network.ignoreVirtualInterfaces` | bool       | true                    | Ignore virtual interfaces  |
| `network.internalHttpPort`        | int        | 8096                    | Internal HTTP port         |
| `network.internalHttpsPort`       | int        | 8920                    | Internal HTTPS port        |
| `network.knownProxies`            | listOf str | ["127.0.0.1"] behind RP | Known proxy IPs            |
| `network.publicHttpPort`          | int        | 8096                    | Public HTTP port           |
| `network.publicHttpsPort`         | int        | 8920                    | Public HTTPS port          |
| `network.requireHttps`            | bool       | false                   | Require HTTPS              |
| `network.certificatePath`         | path       | ""                      | SSL certificate path       |
| `network.certificatePassword`     | secret     | ""                      | Certificate password       |

### jellyfin.encoding

| Option                              | Type        | Default                    | Description                                                  |
| ----------------------------------- | ----------- | -------------------------- | ------------------------------------------------------------ |
| `encoding.hardwareAccelerationType` | enum        | "none"                     | HA type: none/qsv/amf/nvenc/vaapi/rkmpp/videotoolbox/v4l2m2m |
| `encoding.enableHardwareEncoding`   | bool        | true                       | Enable HW encoding                                           |
| `encoding.allowHevcEncoding`        | bool        | false                      | Allow HEVC encoding                                          |
| `encoding.allowAv1Encoding`         | bool        | false                      | Allow AV1 encoding                                           |
| `encoding.encodingThreadCount`      | int         | -1 (auto)                  | Encoding thread count                                        |
| `encoding.transcodingTempPath`      | str         | cacheDir/transcodes        | Temp transcode directory                                     |
| `encoding.vaapiDevice`              | str         | /dev/dri/renderD128        | VAAPI device path                                            |
| `encoding.qsvDevice`                | str         | ""                         | QuickSync device path                                        |
| `encoding.enableTonemapping`        | bool        | false                      | HDR to SDR tonemapping                                       |
| `encoding.tonemappingAlgorithm`     | enum        | "bt2390"                   | Tonemapping algorithm                                        |
| `encoding.tonemappingMode`          | enum        | "auto"                     | Tone mapping mode                                            |
| `encoding.tonemappingDesat`         | number      | 0                          | Desaturation level                                           |
| `encoding.tonemappingPeak`          | number      | 100                        | Peak brightness override                                     |
| `encoding.h264Crf`                  | int         | 23                         | x264 CRF value                                               |
| `encoding.h265Crf`                  | int         | 28                         | x265 CRF value                                               |
| `encoding.encoderPreset`            | enum        | "auto"                     | Encoder preset (placebo to ultrafast)                        |
| `encoding.deinterlaceMethod`        | enum        | "yadif"                    | Deinterlace method                                           |
| `encoding.enableSubtitleExtraction` | bool        | true                       | Extract embedded subtitles                                   |
| `encoding.hardwareDecodingCodecs`   | listOf enum | [h264,hevc,mpeg2video,vc1] | HW decode codecs                                             |
| `encoding.enableThrottling`         | bool        | true                       | Pause transcode when buffered ahead                          |
| `encoding.maxMuxingQueueSize`       | int         | 2048                       | Max muxing queue size                                        |

### jellyfin.system (selected highlights — ~60 options total)

| Option                                     | Type             | Description                                                                              |
| ------------------------------------------ | ---------------- | ---------------------------------------------------------------------------------------- |
| `system.serverName`                        | str              | Server display name                                                                      |
| `system.preferredMetadataLanguage`         | str              | UI/metadata language (e.g. "en")                                                         |
| `system.metadataCountryCode`               | str              | Country code for metadata (e.g. "US")                                                    |
| `system.metadataPath`                      | path             | Artwork/metadata storage path                                                            |
| `system.cacheSize`                         | int (min 3)      | Cache size in GB                                                                         |
| `system.saveMetadataHidden`                | bool             | Save metadata as hidden files                                                            |
| `system.logFileRetentionDays`              | int              | Log file retention days                                                                  |
| `system.minResumePct` / `maxResumePct`     | int              | Resume playback thresholds                                                               |
| `system.libraryScanFanoutConcurrency`      | int              | Concurrent library scans                                                                 |
| `system.libraryMetadataRefreshConcurrency` | int              | Concurrent metadata refreshes                                                            |
| `system.enableMetrics`                     | bool             | Enable Prometheus metrics                                                                |
| `system.enableLegacyAuthorization`         | bool             | Enable legacy auth headers                                                               |
| `system.trickplayOptions`                  | submodule        | Trickplay thumbnail generation (HwAccel, HwEncoding, resolutions, interval, jpegQuality) |
| `system.metadataOptions`                   | listOf submodule | Per-media-type metadata fetcher config                                                   |
| `system.pluginRepositories`                | listOf submodule | Custom plugin repo URLs                                                                  |
| `system.pathSubstitutions`                 | listOf submodule | Path remapping for clients                                                               |
| `system.castReceiverApplications`          | submodule        | Cast receiver config                                                                     |

### jellyfin.libraries

| Option             | Type      | Description                                                                                                                                                                                                                                                                                                  |
| ------------------ | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `libraries.<name>` | submodule | Media library. Fields: `paths`, `collectionType` (movies/tvshows/music/...), `enabled`, `enablePhotos`, `enableRealtimeMonitor`, `enableChapterImageExtraction`, `saveLocalMetadata`, `preferredMetadataLanguage`, `metadataCountryCode`, `subtitleFetcherOrder`, `subtitleDownloadLanguages`, `typeOptions` |

### jellyfin.users

| Option         | Type      | Description                                                                                                                                                                                                                                                                                             |
| -------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `users.<name>` | submodule | User account. Must have at least one admin. Fields: `password`, `policy` (isAdministrator, isHidden, isDisabled, enableContentDeletion, enableMediaPlayback, etc.), `configuration` (groupedFolders, orderedViews, subtitleMode, enableNextEpisodeAutoPlay, etc.), `enableAutoLogin`, `accessSchedules` |

### jellyfin.plugins

| Option           | Type      | Description                                                   |
| ---------------- | --------- | ------------------------------------------------------------- |
| `plugins.<name>` | submodule | Plugin with `enable`, optional `package`, and freeform config |

### jellyfin.branding

| Option                          | Type     | Default | Description           |
| ------------------------------- | -------- | ------- | --------------------- |
| `branding.customCss`            | lines    | ""      | Custom CSS            |
| `branding.loginDisclaimer`      | lines    | ""      | Login page disclaimer |
| `branding.splashscreenEnabled`  | bool     | false   | Enable splashscreen   |
| `branding.splashscreenLocation` | path/str | —       | Splashscreen image    |

---

## `nixflix.sonarr.*` / `nixflix.radarr.*` / `nixflix.sonarr-anime.*` / `nixflix.lidarr.*`

All share the same structure from `mkArrServiceModule` with minor per-service differences.

| Option                       | Type               | Default        | Description                                                                                                              |
| ---------------------------- | ------------------ | -------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `<svc>.enable`               | bool               | false          | Enable the service                                                                                                       |
| `<svc>.package`              | package            | pkgs.<svc>     | Package                                                                                                                  |
| `<svc>.user`                 | str                | <svc>          | Service user                                                                                                             |
| `<svc>.group`                | str                | <svc>          | Service group                                                                                                            |
| `<svc>.dataDir`              | path               | stateDir/<svc> | Data directory                                                                                                           |
| `<svc>.openFirewall`         | bool               | false          | Open firewall ports                                                                                                      |
| `<svc>.subdomain`            | str                | <svc>          | Reverse proxy subdomain                                                                                                  |
| `<svc>.reverseProxy.expose`  | bool               | true           | Expose via RP                                                                                                            |
| `<svc>.vpn.enable`           | bool               | false          | Route through VPN                                                                                                        |
| `<svc>.connectionAddress`    | str                | derived        | Connection address (readOnly)                                                                                            |
| `<svc>.config.apiVersion`    | str                | —              | API version                                                                                                              |
| `<svc>.config.apiKey`        | secret             | —              | API key                                                                                                                  |
| `<svc>.config.hostConfig`    | submodule          | —              | Host config: bindAddress, port, sslPort, username, password, urlBase, instanceName, logLevel, branch, proxyEnabled, etc. |
| `<svc>.config.rootFolders`   | submodule          | —              | Media root folders (per service)                                                                                         |
| `<svc>.config.delayProfiles` | submodule          | —              | Delay profiles                                                                                                           |
| `<svc>.settings`             | freeform submodule | —              | Arbitrary INI settings (app, update, server, log, postgres)                                                              |
| `<svc>.mediaDirs`            | listOf path        | per service    | Media directories (not for prowlarr)                                                                                     |

Per-service defaults:

- **sonarr**: port 8989, branch "main", mediaDirs [mediaDir/tv]
- **radarr**: port 7878, branch "master", mediaDirs [mediaDir/movies]
- **sonarr-anime**: port 8990, branch "main", mediaDirs [mediaDir/anime]
- **lidarr**: port 8686, branch "master", mediaDirs [mediaDir/music]
- **prowlarr**: port 9696, branch "master", mediaDirs []

---

## `nixflix.prowlarr.*` (additional options)

| Option                            | Type             | Description                                                                                                      |
| --------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------- |
| `prowlarr.config.applications`    | listOf submodule | Connected \*arr apps: name, implementationName (Lidarr/Mylar/Radarr/Readarr/Sonarr/Whisparr), apiKey, + freeform |
| `prowlarr.config.indexers`        | listOf submodule | Indexers: name, apiKey, username, password, appProfileId, tags, + freeform                                       |
| `prowlarr.config.indexerProxies`  | listOf submodule | Indexer proxies: name, username, password, tags, + freeform. FlareSolverr auto-configured when enabled.          |
| `prowlarr.config.downloadClients` | listOf submodule | Download client config: name, implementation, host, port, urlBase, apiKey, categories                            |
| `prowlarr.config.tags`            | listOf str       | Tag names to create                                                                                              |

---

## `nixflix.seerr.*`

### Core

| Option                      | Type    | Default        | Description             |
| --------------------------- | ------- | -------------- | ----------------------- |
| `seerr.enable`              | bool    | false          | Enable Seerr            |
| `seerr.package`             | package | pkgs.seerr     | Package                 |
| `seerr.apiKey`              | secret  | —              | API key                 |
| `seerr.user`                | str     | "seerr"        | Service user            |
| `seerr.group`               | str     | "seerr"        | Service group           |
| `seerr.dataDir`             | path    | stateDir/seerr | Data directory          |
| `seerr.port`                | int     | 5055           | Listen port             |
| `seerr.openFirewall`        | bool    | false          | Open firewall           |
| `seerr.subdomain`           | str     | "seerr"        | Reverse proxy subdomain |
| `seerr.reverseProxy.expose` | bool    | true           | Expose via RP           |
| `seerr.vpn.enable`          | bool    | false          | Route through VPN       |

### seerr.jellyfin

| Option                        | Type       | Description                            |
| ----------------------------- | ---------- | -------------------------------------- |
| `jellyfin.adminUsername`      | nullOr str | Jellyfin admin username                |
| `jellyfin.adminPassword`      | secret     | Jellyfin admin password                |
| `jellyfin.hostname`           | str        | Jellyfin hostname                      |
| `jellyfin.port`               | int        | Jellyfin port                          |
| `jellyfin.useSsl`             | bool       | Use SSL                                |
| `jellyfin.urlBase`            | str        | URL base                               |
| `jellyfin.enableAllLibraries` | bool       | true                                   |
| `jellyfin.libraryFilter`      | submodule  | Filter by types (movie/show) and names |

### seerr.radarr

| Option          | Type      | Description                                                                                                                                                                 |
| --------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `radarr.<name>` | submodule | Radarr instance: hostname, port, apiKey, useSsl, baseUrl, activeProfileName, activeDirectory, is4k, minimumAvailability, isDefault, externalUrl, syncEnabled, preventSearch |

### seerr.sonarr

| Option          | Type      | Description                                                                                                                                                                                                                                            |
| --------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `sonarr.<name>` | submodule | Sonarr instance: hostname, port, apiKey, useSsl, baseUrl, activeProfileName, activeDirectory, activeAnimeProfileName, activeAnimeDirectory, seriesType, animeSeriesType, enableSeasonFolders, is4k, isDefault, externalUrl, syncEnabled, preventSearch |

### seerr.settings

| Option                              | Type      | Default                 | Description               |
| ----------------------------------- | --------- | ----------------------- | ------------------------- |
| `settings.users.localLogin`         | bool      | true                    | Allow local account login |
| `settings.users.mediaServerLogin`   | bool      | true                    | Allow media server login  |
| `settings.users.newPlexLogin`       | bool      | true                    | Allow new Plex signup     |
| `settings.users.defaultPermissions` | int       | 32                      | Default permission level  |
| `settings.users.defaultQuotas`      | submodule | {movie:{0,7}, tv:{0,7}} | Default request quotas    |

---

## `nixflix.recyclarr.*`

| Option                 | Type       | Default        | Description                                         |
| ---------------------- | ---------- | -------------- | --------------------------------------------------- |
| `recyclarr.enable`     | bool       | false          | Enable Recyclarr                                    |
| `recyclarr.package`    | package    | pkgs.recyclarr | Recyclarr package                                   |
| `recyclarr.settings`   | yaml lines | —              | Recyclarr YAML config as Nix string                 |
| `recyclarr.configFile` | path       | —              | Path to external recyclarr.yml (overrides settings) |
| `recyclarr.cleanup`    | bool       | false          | Clean up unused custom formats                      |
| `recyclarr.user`       | str        | "recyclarr"    | Service user                                        |
| `recyclarr.group`      | str        | "recyclarr"    | Service group                                       |
| `recyclarr.interval`   | str        | "daily"        | Systemd timer interval (daily/weekly)               |
| `recyclarr.frequency`  | str        | "12:00"        | Time of day to run                                  |

---

## `nixflix.torrentClients.qbittorrent.*`

| Option                            | Type               | Default              | Description                       |
| --------------------------------- | ------------------ | -------------------- | --------------------------------- |
| `qbittorrent.enable`              | bool               | false                | Enable qBittorrent                |
| `qbittorrent.package`             | package            | pkgs.qbittorrent-nox | Package                           |
| `qbittorrent.user`                | str                | "qbittorrent"        | Service user                      |
| `qbittorrent.group`               | str                | "qbittorrent"        | Service group                     |
| `qbittorrent.dataDir`             | path               | stateDir/qbittorrent | Data directory                    |
| `qbittorrent.downloadDir`         | path               | downloadsDir         | Default download directory        |
| `qbittorrent.webuiPort`           | int                | 8080                 | WebUI port                        |
| `qbittorrent.openFirewall`        | bool               | false                | Open firewall                     |
| `qbittorrent.subdomain`           | str                | "qbittorrent"        | Reverse proxy subdomain           |
| `qbittorrent.password`            | secret             | —                    | WebUI password                    |
| `qbittorrent.reverseProxy.expose` | bool               | true                 | Expose via RP                     |
| `qbittorrent.vpn.enable`          | bool               | false                | Route through VPN                 |
| `qbittorrent.connectionAddress`   | str                | derived              | Connection address                |
| `qbittorrent.categories`          | attrsOf path       | {}                   | Download category paths           |
| `qbittorrent.serverConfig`        | freeform submodule | {}                   | Arbitrary qBittorrent.conf fields |

---

## `nixflix.flaresolverr.*`

| Option                       | Type        | Default           | Description                                              |
| ---------------------------- | ----------- | ----------------- | -------------------------------------------------------- |
| `flaresolverr.enable`        | bool        | false             | Enable FlareSolverr                                      |
| `flaresolverr.package`       | package     | pkgs.flaresolverr | Package                                                  |
| `flaresolverr.user`          | str         | "flaresolverr"    | Service user                                             |
| `flaresolverr.group`         | str         | "flaresolverr"    | Service group                                            |
| `flaresolverr.port`          | int         | 8191              | Listen port                                              |
| `flaresolverr.captchaSolver` | nullOr enum | null              | Captcha solver: hcaptcha-solver/recaptcha-solver-v2/none |
| `flaresolverr.vpn.enable`    | bool        | false             | Route through VPN                                        |

---

## `nixflix.usenetClients.sabnzbd.*`

| Option                        | Type               | Default          | Description                     |
| ----------------------------- | ------------------ | ---------------- | ------------------------------- |
| `sabnzbd.enable`              | bool               | false            | Enable SABnzbd                  |
| `sabnzbd.package`             | package            | pkgs.sabnzbd     | Package                         |
| `sabnzbd.user`                | str                | "sabnzbd"        | Service user                    |
| `sabnzbd.group`               | str                | "sabnzbd"        | Service group                   |
| `sabnzbd.dataDir`             | path               | stateDir/sabnzbd | Data directory                  |
| `sabnzbd.port`                | int                | 8080             | WebUI port                      |
| `sabnzbd.openFirewall`        | bool               | false            | Open firewall                   |
| `sabnzbd.subdomain`           | str                | "sabnzbd"        | Reverse proxy subdomain         |
| `sabnzbd.apiKey`              | secret             | —                | API key                         |
| `sabnzbd.nzbKey`              | secret             | —                | NZB key                         |
| `sabnzbd.reverseProxy.expose` | bool               | true             | Expose via RP                   |
| `sabnzbd.vpn.enable`          | bool               | false            | Route through VPN               |
| `sabnzbd.settings`            | freeform submodule | {}               | Arbitrary SABnzbd config fields |

---

## `nixflix.vpn.*`

| Option           | Type | Default | Description                                            |
| ---------------- | ---- | ------- | ------------------------------------------------------ |
| `vpn.enable`     | bool | false   | Enable WireGuard VPN for services                      |
| `vpn.wgConfFile` | path | —       | WireGuard config file path                             |
| `vpn.wgConf`     | str  | —       | WireGuard config as string (alternative to wgConfFile) |

---

## `nixflix.downloadarr.*`

| Option                 | Type     | Description                                            |
| ---------------------- | -------- | ------------------------------------------------------ |
| `downloadarr.enable`   | bool     | Enable Downloadarr (auto-download client configurator) |
| `downloadarr.settings` | freeform | Downloadarr YAML config                                |

---

## `nixflix.postgres.*`

| Option             | Type    | Default            | Description                                     |
| ------------------ | ------- | ------------------ | ----------------------------------------------- |
| `postgres.enable`  | bool    | false              | Enable PostgreSQL (for services that need a DB) |
| `postgres.package` | package | pkgs.postgresql_16 | PostgreSQL package                              |
