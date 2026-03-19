{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  prometheusStateDir = "${cfg.dataDir}/.state/prometheus";
  prometheusListen = "127.0.0.1";
  prometheusPort = 9092;
  nodeExporterPort = 9100;
  prometheusStateDirName = "prometheus";
in
{
  config = lib.mkIf (cfg.enable && cfg.monitoring.enable && cfg.monitoring.metrics.enable) {
    systemd.tmpfiles.rules = [
      "d ${prometheusStateDir} 0750 prometheus prometheus - -"
      "Z ${prometheusStateDir} 0750 prometheus prometheus - -"

      # Prometheus expects /var/lib/${prometheusStateDirName}/data; keep data on /data via symlink.
      "L+ /var/lib/${prometheusStateDirName}/data - - - - ${prometheusStateDir}"
    ];

    services.prometheus = {
      enable = true;
      listenAddress = prometheusListen;
      port = prometheusPort;
      stateDir = prometheusStateDirName;
      globalConfig.scrape_interval = "15s";
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [
            {
              targets = [ "${prometheusListen}:${toString prometheusPort}" ];
            }
          ];
        }
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "${prometheusListen}:${toString nodeExporterPort}" ];
            }
          ];
        }
      ];
    };

    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = prometheusListen;
      port = nodeExporterPort;
      extraFlags = [ "--collector.systemd" ];
    };
  };
}
