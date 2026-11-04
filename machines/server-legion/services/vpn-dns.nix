{ lib, ... }:
{
  systemd.services =
    lib.genAttrs
      [
        "sonarr"
        "sonarr-anime"
        "radarr"
        "prowlarr"
        "qbittorrent"
        "flaresolverr"
      ]
      (_: {
        # resolved replaces its stub atomically; keep the VPN bind's parent private.
        serviceConfig.TemporaryFileSystem = [ "/run/systemd/resolve:ro" ];
      });
}
