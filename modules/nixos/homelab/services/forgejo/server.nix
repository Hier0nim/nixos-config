{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  forgejoCfg = cfg.services.forgejo;

  snapshotDir = "${cfg.state.root}/forgejo-backup";
  snapshotTmpDir = "${snapshotDir}.new";
  snapshotOldDir = "${snapshotDir}.old";
  forgejoStateDir = config.services.forgejo.stateDir;
  forgejoService = "forgejo.service";
  systemctl = "${pkgs.systemd}/bin/systemctl";
in
{
  config = lib.mkIf (cfg.enable && forgejoCfg.enable) {
    services.forgejo = {
      enable = true;
      database.type = "sqlite3";
      lfs.enable = true;
      dump.enable = false;

      settings = {
        server = {
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = forgejoCfg.upstream.port;
          DOMAIN = "${forgejoCfg.expose.subdomain}.${cfg.domain}";
          ROOT_URL = "https://${forgejoCfg.expose.subdomain}.${cfg.domain}/";
          SSH_PORT = 22;
          SSH_USER = "forgejo";
          DISABLE_SSH = false;
        };
        session.COOKIE_SECURE = true;
        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = true;
        };
        "cron.cleanup_offline_runners" = {
          ENABLED = true;
          SCHEDULE = "@midnight";
          GLOBAL_SCOPE_ONLY = true;
          OLDER_THAN = "24h";
        };
        repository.DEFAULT_PRIVATE = "private";
      };
    };

    environment.systemPackages = [
      config.services.forgejo.package
      pkgs.sqlite
    ];

    systemd.services.homelab-forgejo-snapshot = {
      after = [ "homelab-state-root.service" ];
      requires = [ "homelab-state-root.service" ];
      description = "Create a consistent Forgejo backup snapshot";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          forgejoStateDir
          cfg.state.root
        ];
      };
      path = [
        pkgs.coreutils
        pkgs.findutils
      ];
      script = ''
        set -euo pipefail

        was_active=false
        cleanup() {
          status=$?
          trap - EXIT
          rm -rf ${lib.escapeShellArg snapshotTmpDir}
          if [ ! -e ${lib.escapeShellArg snapshotDir} ] && [ -e ${lib.escapeShellArg snapshotOldDir} ]; then
            mv -T ${lib.escapeShellArg snapshotOldDir} ${lib.escapeShellArg snapshotDir} || status=1
          fi
          if "$was_active" && ! ${systemctl} start ${forgejoService}; then
            status=1
          fi
          exit "$status"
        }
        trap cleanup EXIT

        if ${systemctl} is-active --quiet ${forgejoService}; then
          was_active=true
          ${systemctl} stop ${forgejoService}
        fi

        rm -rf ${lib.escapeShellArg snapshotTmpDir}
        mkdir -m 0700 ${lib.escapeShellArg snapshotTmpDir}
        cp -a --reflink=auto ${lib.escapeShellArg "${forgejoStateDir}/."} ${lib.escapeShellArg snapshotTmpDir}

        if [ -e ${lib.escapeShellArg snapshotOldDir} ]; then
          if [ -e ${lib.escapeShellArg snapshotDir} ]; then
            rm -rf ${lib.escapeShellArg snapshotOldDir}
          else
            mv -T ${lib.escapeShellArg snapshotOldDir} ${lib.escapeShellArg snapshotDir}
          fi
        fi
        if [ -e ${lib.escapeShellArg snapshotDir} ]; then
          mv -T ${lib.escapeShellArg snapshotDir} ${lib.escapeShellArg snapshotOldDir}
        fi
        mv -T ${lib.escapeShellArg snapshotTmpDir} ${lib.escapeShellArg snapshotDir}
        rm -rf ${lib.escapeShellArg snapshotOldDir}
      '';
    };

    homelab.services.forgejo.backup = {
      enable = true;
      paths = [ snapshotDir ];
      prepareServices = [ "homelab-forgejo-snapshot.service" ];
    };

    assertions = [
      {
        assertion = forgejoCfg.upstream.host == "127.0.0.1";
        message = "Forgejo must remain bound to 127.0.0.1 and be exposed only through Caddy.";
      }
    ];
  };
}
