{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  enableActualService = cfg.services."enable-actual";
  enableActualFqdn = "${enableActualService.expose.subdomain}.${cfg.domain}";
  actualFqdn = "${cfg.services.actual.expose.subdomain}.${cfg.domain}";
in
{
  config = lib.mkIf (cfg.enable && enableActualService.enable) {
    homelab.services."enable-actual".backup = {
      enable = lib.mkDefault true;
      paths = lib.mkDefault [ cfg.state.enableActual ];
    };

    virtualisation = {
      docker.enable = true;
      oci-containers = {
        backend = lib.mkDefault "docker";

        containers."enable-actual" = {
          autoStart = true;
          inherit (enableActualService) image;
          ports = [
            "127.0.0.1:${toString enableActualService.upstream.port}:${toString enableActualService.upstream.port}"
          ];
          volumes = [
            "${cfg.state.enableActual}:/data"
          ];
          environment = {
            PORT = toString enableActualService.upstream.port;
            DATA_DIR = "/data";
            PUBLIC_URL = "https://${enableActualFqdn}";
            ACTUAL_URL = "https://${actualFqdn}";
          };
          extraOptions = [
            "--user=0:0"
          ];
        };
      };
    };
  };
}
