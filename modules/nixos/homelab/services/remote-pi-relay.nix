{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  relayService = cfg.services."remote-pi-relay";
  relayState = "${cfg.state.root}/remote-pi-relay";
in
{
  config = lib.mkIf (cfg.enable && relayService.enable) {
    homelab.apps."remote-pi-relay" = {
      enable = true;
      user = "root";
      group = "root";
      serviceNames = [ "docker-remote-pi-relay" ];
      state.paths = [ relayState ];
      state.mode = "0750";
    };

    homelab.services."remote-pi-relay" = {
      backup = {
        enable = lib.mkDefault true;
        paths = lib.mkDefault [ relayState ];
      };

      expose.reverseProxyExtraConfig = lib.mkDefault ''
        health_uri /health
        health_interval 30s
        flush_interval -1
      '';
    };

    virtualisation = {
      docker.enable = true;
      oci-containers = {
        backend = lib.mkDefault "docker";

        containers."remote-pi-relay" = {
          autoStart = true;
          inherit (relayService) image;
          ports = [
            "127.0.0.1:${toString relayService.upstream.port}:3000"
          ];
          volumes = [
            "${relayState}:/data"
          ];
          environment = {
            REMOTEPI_RELAY_PORT = "3000";
            REMOTEPI_MESH_DB_PATH = "/data/mesh.db";
            RUST_LOG = "info";
          };
        };
      };
    };
  };
}
