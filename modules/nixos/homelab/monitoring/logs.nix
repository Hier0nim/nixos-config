{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  lokiStateDir = "${cfg.dataDir}/.state/loki";
  promtailStateDir = "${cfg.dataDir}/.state/monitoring/promtail";
  promtailPositions = "${promtailStateDir}/positions.yaml";
  lokiListen = "127.0.0.1";
  lokiPort = 3100;
in
{
  config = lib.mkIf (cfg.enable && cfg.monitoring.enable && cfg.monitoring.logs.enable) {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/.state/monitoring 0755 root root - -"
      "d ${promtailStateDir} 0750 promtail promtail - -"
      "Z ${promtailStateDir} 0750 promtail promtail - -"
      "d ${lokiStateDir} 0750 loki loki - -"
      "Z ${lokiStateDir} 0750 loki loki - -"
    ];

    users.users.promtail.extraGroups = [ "systemd-journal" ];

    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_address = lokiListen;
          http_listen_port = lokiPort;
        };
        common = {
          path_prefix = lokiStateDir;
          replication_factor = 1;
          ring.kvstore.store = "inmemory";
          storage.filesystem = {
            chunks_directory = "${lokiStateDir}/chunks";
            rules_directory = "${lokiStateDir}/rules";
          };
        };
        schema_config = {
          configs = [
            {
              from = "2024-01-01";
              store = "boltdb-shipper";
              object_store = "filesystem";
              schema = "v11";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
        storage_config = {
          boltdb_shipper = {
            active_index_directory = "${lokiStateDir}/index";
            cache_location = "${lokiStateDir}/cache";
          };
          filesystem.directory = "${lokiStateDir}/chunks";
        };
        limits_config = {
          retention_period = "168h";
          allow_structured_metadata = false;
        };
      };
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = 9080;
          grpc_listen_address = "127.0.0.1";
          grpc_listen_port = 0;
        };
        positions.filename = promtailPositions;
        clients = [
          {
            url = "http://${lokiListen}:${toString lokiPort}/loki/api/v1/push";
          }
        ];
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.networking.hostName;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
              {
                source_labels = [ "__journal__transport" ];
                target_label = "transport";
              }
            ];
          }
        ];
      };
    };
  };
}
