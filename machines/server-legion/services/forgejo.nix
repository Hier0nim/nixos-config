{
  config,
  lib,
  pkgs,
  ...
}:
let
  forgejoStateDir = config.services.forgejo.stateDir;
  snapshotDir = "/var/lib/homelab/forgejo-backup";
  snapshotTmpDir = "${snapshotDir}.new";
  snapshotOldDir = "${snapshotDir}.old";
  runnerTokenFile = config.clan.core.vars.generators.forgejo-runner.files."token.env".path;
  systemctl = "${pkgs.systemd}/bin/systemctl";
in
{
  clan.core.vars.generators.forgejo-runner = {
    files."token.env" = {
      owner = "gitea-runner";
      group = "gitea-runner";
      mode = "0400";
    };
    prompts."token.env" = {
      description = "Forgejo Actions runner environment file";
      type = "multiline-hidden";
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      install -m 0400 "$prompts/token.env" "$out/token.env"
    '';
  };

  services.forgejo = {
    enable = true;
    database.type = "sqlite3";
    lfs.enable = true;
    dump.enable = false;
    settings = {
      server = {
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        DOMAIN = "git.pieczarkowo.me";
        ROOT_URL = "https://git.pieczarkowo.me/";
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

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.global = {
      enable = true;
      name = "server-legion-forgejo-ci";
      url = "http://127.0.0.1:3000";
      tokenFile = runnerTokenFile;
      labels = [ "nix:host" ];
      hostPackages = with pkgs; [
        bash
        coreutils
        git
        curl
        nodejs_24
        nix
        zstd
      ];
      settings = {
        runner = {
          capacity = 1;
          timeout = "3h";
        };
        host.workdir_parent = "/var/lib/gitea-runner/global/work";
        cache = {
          enabled = true;
          dir = "/var/lib/gitea-runner/global/actions-cache";
        };
      };
    };
  };

  users.groups.gitea-runner = { };
  users.users.gitea-runner = {
    isSystemUser = true;
    group = "gitea-runner";
    home = "/var/lib/gitea-runner";
    createHome = false;
  };

  nix.settings = {
    sandbox = true;
    sandbox-fallback = false;
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/homelab 0755 root root - -"
      "d ${snapshotDir} 0700 root root - -"
      "d /var/lib/gitea-runner 0700 gitea-runner gitea-runner - -"
      "d /var/lib/gitea-runner/global 0700 gitea-runner gitea-runner - -"
      "d /var/lib/gitea-runner/global/work 0700 gitea-runner gitea-runner - -"
      "d /var/lib/gitea-runner/global/actions-cache 0700 gitea-runner gitea-runner - -"
    ];
    services = {
      forgejo-snapshot = {
        description = "Create a consistent Forgejo backup snapshot";
        unitConfig.RequiresMountsFor = [
          forgejoStateDir
          snapshotDir
        ];
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
            "/var/lib/homelab"
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
            if "$was_active" && ! ${systemctl} start forgejo.service; then
              status=1
            fi
            exit "$status"
          }
          trap cleanup EXIT

          if ${systemctl} is-active --quiet forgejo.service; then
            was_active=true
            ${systemctl} stop forgejo.service
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

      gitea-runner-global = {
        serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "gitea-runner";
          Group = "gitea-runner";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          RestrictSUIDSGID = true;
          UMask = "0077";
          ReadWritePaths = [ "/var/lib/gitea-runner" ];
          InaccessiblePaths = [ "/var/lib/homelab" ];
        };
      };
    };
  };

  assertions = [
    {
      assertion = config.nix.settings.sandbox or false;
      message = "The native Forgejo runner requires Nix sandboxing to remain enabled.";
    }
    {
      assertion = !(config.nix.settings.sandbox-fallback or false);
      message = "The native Forgejo runner requires nix.settings.sandbox-fallback = false.";
    }
  ];
}
