{
  config,
  lib,
  pkgs,
  ...
}:
let
  forgejoStateDir = config.services.forgejo.stateDir;
  domain = config.services.homelabIngress.domain;
  clientFiles = config.clan.core.vars.generators.forgejo-oidc.files;
  snapshotDir = "/var/lib/homelab/forgejo-backup";
  snapshotTmpDir = "${snapshotDir}.new";
  snapshotOldDir = "${snapshotDir}.old";
  runnerTokenFile = config.clan.core.vars.generators.forgejo-runner.files."token.env".path;
  systemctl = "${pkgs.systemd}/bin/systemctl";
  sourceArgs = [
    "--name"
    "authelia"
    "--provider"
    "openidConnect"
    "--key"
    "forgejo"
    "--auto-discover-url"
    "https://auth.${domain}/.well-known/openid-configuration"
    "--scopes"
    "openid"
    "--scopes"
    "email"
    "--scopes"
    "profile"
    "--skip-local-2fa"
    "--group-claim-name"
    ""
    "--admin-group"
    ""
    "--restricted-group"
    ""
    "--group-team-map"
    ""
    "--group-team-map-removal=false"
    "--attribute-ssh-public-key"
    ""
    "--allow-username-change=false"
  ];
  sourceConfigHash = builtins.hashString "sha256" (builtins.toJSON sourceArgs);
in
{
  clan.core.vars.generators.forgejo-oidc = {
    files = lib.genAttrs [ "client-secret" "client-hash" ] (_: {
      owner = "root";
      group = "root";
      mode = "0400";
    });
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.argon2-cffi ])) ];
    script = "python3 ${../identity/generate-oidc-client.py}";
  };

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

  services = {
    authelia.instances.homelab.settings.identity_providers.oidc = {
      authorization_policies.forgejo = {
        default_policy = "deny";
        rules = [
          {
            policy = "two_factor";
            subject = [
              [
                "user:hieronim"
                "group:infra-admin"
              ]
            ];
          }
        ];
      };
      clients = [
        {
          client_id = "forgejo";
          client_name = "Forgejo";
          client_secret = ''{{ mustEnv "CREDENTIALS_DIRECTORY" | printf "%s/forgejo-client-hash" | secret }}'';
          public = false;
          authorization_policy = "forgejo";
          consent_mode = "implicit";
          require_pkce = true;
          pkce_challenge_method = "S256";
          redirect_uris = [ "https://git.${domain}/user/oauth2/authelia/callback" ];
          scopes = [
            "openid"
            "email"
            "profile"
          ];
          response_types = [ "code" ];
          grant_types = [ "authorization_code" ];
          token_endpoint_auth_method = "client_secret_basic";
          id_token_signed_response_alg = "RS256";
        }
      ];
    };
    forgejo = {
      enable = true;
      # The pinned CLI otherwise accepts OAuth secrets only through exposed argv.
      package = pkgs.forgejo-lts.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./forgejo-oauth-secret-env.patch ];
      });
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
        oauth2_client = {
          ENABLE_AUTO_REGISTRATION = false;
          ACCOUNT_LINKING = "login";
          OPENID_CONNECT_SCOPES = "openid email profile";
          UPDATE_AVATAR = false;
        };
        # Router/access logs can contain authorization codes in callback query strings.
        log = {
          DISABLE_ROUTER_LOG = true;
          ENABLE_ACCESS_LOG = false;
        };
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

    gitea-actions-runner = {
      package = pkgs.gitea-actions-runner;
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
      authelia-homelab.serviceConfig.LoadCredential = [
        "forgejo-client-hash:${clientFiles.client-hash.path}"
      ];
      forgejo = {
        after = [ "authelia-homelab.service" ];
        path = [ pkgs.gawk ];
        serviceConfig.LoadCredential = [ "oidc-client-secret:${clientFiles.client-secret.path}" ];
        preStart = lib.mkAfter ''
          # Updating an unchanged source requires discovery and would break offline restarts.
          digest=$(sha256sum "$CREDENTIALS_DIRECTORY/oidc-client-secret")
          expected="${sourceConfigHash}:''${digest%% *}"
          marker="$FORGEJO_WORK_DIR/.authelia-source"
          if [ ! -f "$marker" ] || [ "$(cat "$marker")" != "$expected" ]; then
            source_id=$(forgejo admin auth list | awk '$2 == "authelia" && $1 ~ /^[0-9]+$/ { print $1 }')
            if [ -n "$source_id" ]; then
              set -- update-oauth --id "$source_id"
            else
              set -- add-oauth
            fi
            export FORGEJO_OAUTH_CLIENT_SECRET="$(cat "$CREDENTIALS_DIRECTORY/oidc-client-secret")"
            test -n "$FORGEJO_OAUTH_CLIENT_SECRET"
            if ! forgejo admin auth "$@" ${lib.escapeShellArgs sourceArgs} > /dev/null 2>&1; then
              echo "Forgejo OIDC source setup failed" >&2
              exit 1
            fi
            unset FORGEJO_OAUTH_CLIENT_SECRET
            (umask 077; printf '%s' "$expected" > "$marker")
          fi
        '';
      };
      forgejo-snapshot = {
        description = "Create a consistent Forgejo backup snapshot";
        unitConfig.RequiresMountsFor = [
          forgejoStateDir
          snapshotDir
          "/var/backup/homelab"
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
            "/var/backup/homelab"
          ];
        };
        path = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.util-linux
        ];
        script = ''
          set -euo pipefail
          exec 9>/var/backup/homelab/.state.lock
          flock -n 9 || { echo "Another state snapshot or restore is running" >&2; exit 1; }
          was_active=false
          cleanup() {
            status=$?
            trap - EXIT INT TERM
            rm -rf ${lib.escapeShellArg snapshotTmpDir} || status=1
            if [ ! -e ${lib.escapeShellArg snapshotDir} ] && [ -e ${lib.escapeShellArg snapshotOldDir} ]; then
              mv -T ${lib.escapeShellArg snapshotOldDir} ${lib.escapeShellArg snapshotDir} || status=1
            fi
            if "$was_active" && ! ${systemctl} start forgejo.service; then
              status=1
            fi
            exit "$status"
          }
          trap cleanup EXIT
          trap 'exit 130' INT
          trap 'exit 143' TERM

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
