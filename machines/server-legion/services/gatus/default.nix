{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.gatus;
  notify = config.services.ntfy-sh.enable;
  files = config.clan.core.vars.generators.gatus.files;
  alerts = lib.optional notify {
    type = "ntfy";
    failure-threshold = 3;
    success-threshold = 2;
    send-on-resolved = true;
    minimum-reminder-interval = "0";
  };
  endpoints = import ./endpoints.nix { inherit config lib; };
in
{
  services = {
    gatus = {
      enable = lib.mkDefault true;
      environmentFile = files.environment.path;
      settings = {
        web = {
          address = "127.0.0.1";
          port = 8083;
        };
        metrics = false;
        # SQLite aggregates uptime for 30 days independently of the recent-results limit.
        storage = {
          type = "sqlite";
          path = "/var/lib/gatus/data.db";
          maximum-number-of-results = 100;
          maximum-number-of-events = 100;
        };
        ui.title = "Pieczarkowo status";
        endpoints = map (
          endpoint:
          endpoint
          // {
            interval = "60s";
            inherit alerts;
            ui = {
              hide-url = true;
              hide-conditions = true;
              hide-hostname = true;
              hide-port = true;
              hide-errors = true;
              dont-resolve-failed-conditions = true;
            };
          }
        ) endpoints;
        external-endpoints = [
          {
            name = "Storage Box";
            group = "Backups";
            token = "\${GATUS_BACKUP_TOKEN}";
            heartbeat.interval = "26h";
            # A daily job failure must not wait for three failed daily backups.
            alerts = map (
              alert:
              alert
              // {
                failure-threshold = 1;
                success-threshold = 1;
              }
            ) alerts;
          }
        ];
      }
      // lib.optionalAttrs notify {
        alerting.ntfy = {
          url = "http://127.0.0.1:2586";
          topic = "infra";
          token = "\${GATUS_NTFY_TOKEN}";
          priority = 3;
          click = "https://status.${config.services.homelabIngress.domain}";
        };
      };
    };
    homelabIngress.services.status = lib.mkIf cfg.enable {
      upstream = "http://127.0.0.1:8083";
      transport = "direct";
      auth = "proxy";
      group = "infra-admin";
    };
    # Keep the existing UID guards; only Caddy can reach these private listeners.
    caddy.virtualHosts."http://127.0.0.1:8086" = lib.mkIf cfg.enable {
      listenAddresses = [ "127.0.0.1" ];
      logFormat = null;
      extraConfig = ''
        request_header -Cookie
        request_header -Authorization
        request_header -Proxy-Authorization
        request_header -Remote-*
        request_header -X-Forwarded-User
        request_header -X-Copyparty-*
        @write not method GET HEAD
        respond @write 405
        handle /gatus-status/api/v1/endpoints/statuses {
          rewrite * /api/v1/endpoints/statuses?page=1&pageSize=1
          reverse_proxy 127.0.0.1:8083
        }
        ${lib.optionalString config.services.actual.enable ''
          handle /actual {
            rewrite * /health?
            reverse_proxy 127.0.0.1:3101
          }
        ''}
        ${lib.optionalString config.services.copyparty.enable ''
          handle /copyparty {
            rewrite * /?
            reverse_proxy 127.0.0.1:3923
          }
        ''}
        respond 404
      '';
    };
  };

  clan.core.vars.generators.gatus = {
    dependencies = lib.optional notify "ntfy";
    files = lib.genAttrs [ "environment" "backup-curl.conf" ] (_: {
      deploy = cfg.enable;
      owner = "root";
      group = "root";
      mode = "0400";
    });
    runtimeInputs = [ pkgs.python3 ];
    script = ''
      python3 - <<'PY'
      import os, secrets
      from pathlib import Path
      out = Path(os.environ['out'])
      token = secrets.token_hex(32)
      publisher = ${
        if notify then "(Path(os.environ['in']) / 'ntfy/gatus-token').read_text().strip()" else "''"
      }
      (out / 'environment').write_text('GATUS_BACKUP_TOKEN=' + token + '\nGATUS_NTFY_TOKEN=' + publisher + '\n')
      (out / 'backup-curl.conf').write_text('header = "Authorization: Bearer ' + token + '"\n')
      for p in out.iterdir(): p.chmod(0o400)
      PY
    '';
  };

  systemd.services.borgbackup-job-hetzner-storagebox = lib.mkIf cfg.enable {
    serviceConfig.LoadCredential = [ "gatus-backup-curl:${files."backup-curl.conf".path}" ];
    # A notification failure must not change the result of a completed backup.
    postStop = ''
      success=false
      if [ "$SERVICE_RESULT" = success ]; then success=true; fi
      ${pkgs.curl}/bin/curl --silent --show-error --fail --connect-timeout 3 --max-time 10 \
        --config "$CREDENTIALS_DIRECTORY/gatus-backup-curl" --request POST \
        "http://127.0.0.1:8083/api/v1/endpoints/backups_storage-box/external?success=$success" \
        --output /dev/null || echo 'Could not report backup result to Gatus' >&2
    '';
  };
}
