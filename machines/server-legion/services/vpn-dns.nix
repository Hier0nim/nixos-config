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
      })
    // {
      wg = {
        # WG setup needs the host stub target and DNS for its endpoint.
        wants = [ "systemd-resolved.service" ];
        after = [ "systemd-resolved.service" ];
      };
    };
}
