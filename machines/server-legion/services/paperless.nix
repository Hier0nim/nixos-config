{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.paperless;
  files = config.clan.core.vars.generators.paperless-oidc.files;
in
{
  services.paperless = {
    enable = lib.mkDefault true;
    address = "127.0.0.1";
    port = 28981;
    dataDir = "/data/paperless";
    consumptionDirIsPublic = false;
    environmentFile = lib.mkIf cfg.enable files.environment.path;
    settings = {
      PAPERLESS_URL = "https://dokumenty.${config.services.homelabIngress.domain}";
      PAPERLESS_OCR_LANGUAGE = "pol+eng";
      PAPERLESS_TASK_WORKERS = 1;
      PAPERLESS_THREADS_PER_WORKER = 2;
      PAPERLESS_TIME_ZONE = config.time.timeZone;
      PAPERLESS_AI_ENABLED = false;
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      PAPERLESS_DISABLE_REGULAR_LOGIN = true;
      PAPERLESS_ACCOUNT_ALLOW_SIGNUPS = false;
      # Only the household-admitted Authelia client can provision an SSO account.
      PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = true;
      PAPERLESS_SOCIAL_AUTO_SIGNUP = true;
      PAPERLESS_SOCIAL_ACCOUNT_DEFAULT_GROUPS = "household";
      PAPERLESS_ENABLE_HTTP_REMOTE_USER = false;
      PAPERLESS_PRE_CONSUME_SCRIPT = pkgs.writeShellScript "paperless-pdf-images-only" ''
        case "$(${pkgs.file}/bin/file --brief --mime-type -- "$DOCUMENT_WORKING_PATH")" in
          application/pdf|image/*) ;;
          *) echo 'Only PDFs and images are accepted' >&2; exit 1 ;;
        esac
      '';
      PAPERLESS_PROXY_SSL_HEADER = [
        "HTTP_X_FORWARDED_PROTO"
        "https"
      ];
    };
  };
  systemd.targets.paperless-state = lib.mkIf cfg.enable {
    description = "Paperless daemons quiesced together for consistent backups";
    wantedBy = [ "multi-user.target" ];
    wants = map (name: "${name}.service") [
      "paperless-web"
      "paperless-scheduler"
      "paperless-task-queue"
    ];
  };
  systemd.services = lib.mkMerge [
    (lib.genAttrs [ "paperless-web" "paperless-scheduler" "paperless-task-queue" ] (
      _:
      lib.mkIf cfg.enable {
        partOf = [ "paperless-state.target" ];
        unitConfig.RequiresMountsFor = [ cfg.dataDir ];
      }
    ))
    (lib.mkIf cfg.enable {
      # Uploads enqueue consumption directly; no filesystem drop-folder watcher.
      paperless-consumer.enable = false;
      paperless-scheduler.wants = lib.mkForce [
        "paperless-web.service"
        "paperless-task-queue.service"
      ];
    })
  ];
  services.homelabIngress.services.dokumenty = lib.mkIf cfg.enable {
    upstream = "http://127.0.0.1:28981";
    transport = "direct";
    auth = "native";
  };
}
