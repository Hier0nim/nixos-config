{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  grafanaFqdn = "${cfg.services.grafana.subdomain}.${cfg.domain}";
  grafanaStateDir = "${cfg.dataDir}/.state/grafana";
  dashboardsDir = "/etc/grafana/dashboards";
  grafanaSecretsFile = "${config.custom.repoPath}/secrets/${config.networking.hostName}/grafana.yaml";
in
{
  config = lib.mkIf (cfg.enable && cfg.monitoring.enable && cfg.monitoring.grafana.enable) {
    sops.secrets = {
      grafana_admin_user = {
        sopsFile = grafanaSecretsFile;
        key = "admin_user";
        owner = "grafana";
        group = "grafana";
        mode = "0400";
      };
      grafana_admin_password = {
        sopsFile = grafanaSecretsFile;
        key = "admin_password";
        owner = "grafana";
        group = "grafana";
        mode = "0400";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${grafanaStateDir} 0750 grafana grafana - -"
      "Z ${grafanaStateDir} 0750 grafana grafana - -"
    ];

    services.grafana = {
      enable = true;
      dataDir = grafanaStateDir;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
          domain = grafanaFqdn;
          root_url = "https://${grafanaFqdn}/";
        };
        security = {
          admin_user = "$__file{${config.sops.secrets.grafana_admin_user.path}}";
          admin_password = "$__file{${config.sops.secrets.grafana_admin_password.path}}";
        };
      };
      provision = {
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:9092";
              isDefault = true;
              uid = "prometheus";
            }
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:3100";
              uid = "loki";
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "homelab";
              type = "file";
              options.path = dashboardsDir;
            }
          ];
        };
      };
    };

    environment.etc."grafana/dashboards/host-overview.json".source = ./dashboards/host-overview.json;
  };
}
