{
  config,
  lib,
  pkgs,
  ...
}:
let
  identity = config.services.authelia.instances.homelab;
  domain = config.services.homelabIngress.domain;
  files = config.clan.core.vars.generators.authelia-secrets.files;
  userSeed = config.clan.core.vars.generators.authelia-users.files."users_database.yml".path;
  smtpPassword = config.clan.core.vars.generators.authelia-smtp.files.password.path;
  oidcFiles = config.clan.core.vars.generators.authelia-oidc.files;
  groupPolicy = group: if group == "household" then "one_factor" else "two_factor";
  proxyServices = lib.filterAttrs (
    _: service: service.auth == "proxy"
  ) config.services.homelabIngress.services;
in
{
  assertions = [
    {
      assertion = !identity.enable || (identity.settings.notifier.smtp.address or "") != "";
      message = "Authelia requires an SMTP relay and runtime credentials.";
    }
  ];

  clan.core.vars.generators = lib.mkMerge [
    {
      authelia-smtp = {
        files.password = {
          owner = "root";
          group = "root";
          mode = "0400";
          deploy = identity.enable;
        };
        prompts.password = {
          description = "Brevo SMTP key for Authelia, not the Brevo account password or HTTP API key";
          type = "hidden";
        };
        runtimeInputs = [ pkgs.coreutils ];
        script = ''
          test -s "$prompts/password"
          install -m 0400 "$prompts/password" "$out/password"
        '';
      };
      authelia-users = {
        files."users_database.yml" = {
          owner = "root";
          group = "root";
          mode = "0400";
          deploy = identity.enable;
        };
        prompts = {
          hieronim-password = {
            description = "Initial Authelia password for hieronim; use a unique long password";
            type = "hidden";
          };
          sarcia-password = {
            description = "Initial Authelia password for sarcia; use a unique long password";
            type = "hidden";
          };
        };
        runtimeInputs = [
          (pkgs.python3.withPackages (ps: [
            ps.argon2-cffi
            ps.pyyaml
          ]))
        ];
        script = ''
          umask 077
          python3 - <<'PY'
          import os
          from pathlib import Path

          from argon2 import PasswordHasher, Type
          import yaml

          hasher = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4,
                                  hash_len=32, salt_len=16, type=Type.ID)
          users = {}
          for name, email, groups in [
              ("hieronim", "hieronimdaniel@proton.me", ["media-admin", "infra-admin", "household", "finance"]),
              ("sarcia", "rossonobile123@gmail.com", ["household", "finance"]),
          ]:
              password = (Path(os.environ["prompts"]) / (name + "-password")).read_bytes()
              if not password:
                  raise SystemExit("Initial passwords must not be empty")
              users[name] = {
                  "displayname": name.capitalize(),
                  "email": email,
                  "password": hasher.hash(password),
                  "groups": groups,
              }
          database = Path(os.environ["out"]) / "users_database.yml"
          database.write_text(yaml.safe_dump({"users": users}, sort_keys=False))
          database.chmod(0o400)
          PY
        '';
      };
    }
    (lib.mkIf identity.enable {
      authelia-oidc = {
        files = lib.genAttrs [ "issuer-key" "hmac-secret" ] (_: {
          owner = "root";
          group = "root";
          mode = "0400";
        });
        runtimeInputs = [ pkgs.openssl ];
        script = ''
          umask 077
          openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$out/issuer-key"
          openssl rand -hex 48 > "$out/hmac-secret"
          chmod 0400 "$out"/*
        '';
      };
      authelia-secrets = {
        files = {
          "jwt-secret" = {
            owner = "root";
            group = "root";
            mode = "0400";
          };
          "storage-encryption-key" = {
            owner = "root";
            group = "root";
            mode = "0400";
          };
        };
        runtimeInputs = [ pkgs.openssl ];
        script = ''
          umask 077
          openssl rand -hex 48 > "$out/jwt-secret"
          openssl rand -hex 48 > "$out/storage-encryption-key"
          chmod 0400 "$out"/*
        '';
      };
    })
  ];

  services = {
    # Only auth uses the tunnel; application DNS records stay direct.
    homelabIngress.services.auth =
      lib.mkIf (identity.enable && config.services.homelabIngress.enableTunnel)
        {
          upstream = "http://127.0.0.1:9091";
          transport = "tunnel";
          auth = "native";
        };
    caddy.virtualHosts."auth.${domain}" = lib.mkIf identity.enable {
      useACMEHost = domain;
      # The portal owns its peer/header boundary instead of the default registry route.
      extraConfig = lib.mkForce ''
        route {
          # Router-masqueraded peers must not bypass the direct-origin restriction.
          @router remote_ip 192.168.8.1
          respond @router 403
          @outside-lan not remote_ip 127.0.0.1 ::1 ${lib.concatStringsSep " " config.services.homelabIngress.lanCidrs}
          respond @outside-lan 403
          ${lib.optionalString config.services.homelabIngress.enableTunnel ''
            @cloudflared {
              remote_ip 127.0.0.1 ::1
              header CF-Connecting-IP *
            }
            handle @cloudflared {
              reverse_proxy 127.0.0.1:9091 {
                header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
                header_up X-Real-IP {http.request.header.CF-Connecting-IP}
                header_up -Forwarded
              }
            }
          ''}
          handle {
            reverse_proxy 127.0.0.1:9091 {
              header_up X-Real-IP {remote_host}
              header_up -CF-Connecting-IP
              header_up -Forwarded
            }
          }
        }
      '';
    };
    authelia.instances.homelab = {
      enable = true;
      environmentVariables.AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = "%d/smtp-password";
      secrets = {
        jwtSecretFile = files."jwt-secret".path;
        storageEncryptionKeyFile = files."storage-encryption-key".path;
        oidcIssuerPrivateKeyFile = oidcFiles.issuer-key.path;
        oidcHmacSecretFile = oidcFiles.hmac-secret.path;
      };
      settings = {
        server.address = "tcp://127.0.0.1:9091/";
        log.level = "info";
        default_2fa_method = "totp";
        authentication_backend.file = {
          path = "/var/lib/authelia-homelab/users_database.yml";
          watch = true;
        };
        access_control = {
          default_policy = "deny";
          rules = lib.concatLists (
            lib.mapAttrsToList (
              name: service:
              let
                rule = {
                  domain = "${name}.${domain}";
                  subject = "group:${service.group}";
                  policy = groupPolicy service.group;
                };
              in
              lib.optional (rule.policy == "two_factor") {
                inherit (rule) domain;
                # Both conditions must match; the MFA exception must not grant access.
                subject = [
                  [
                    "user:sarcia"
                    rule.subject
                  ]
                ];
                policy = "one_factor";
              }
              ++ [ rule ]
            ) proxyServices
          );
        };
        session.cookies = [
          {
            inherit domain;
            authelia_url = "https://auth.${domain}";
            default_redirection_url = "https://grzybflix.${domain}";
            same_site = "lax";
            inactivity = "5 minutes";
            expiration = "1 hour";
            remember_me = "1 month";
          }
        ];
        storage.local.path = "/var/lib/authelia-homelab/db.sqlite3";
        # An SMTP outage must not prevent offline startup for already enrolled users.
        notifier = {
          disable_startup_check = true;
          smtp = {
            address = "smtp://smtp-relay.brevo.com:587";
            username = "b0115f001@smtp-brevo.com";
            sender = "Pieczarkowo <no-reply@pieczarkowo.me>";
            disable_require_tls = false;
            tls.skip_verify = false;
          };
        };
      };
    };
  };

  systemd.services.authelia-homelab = lib.mkIf identity.enable {
    path = [ pkgs.coreutils ];
    serviceConfig = {
      UMask = "0077";
      LoadCredential = [
        "users_database.yml:${userSeed}"
        "smtp-password:${smtpPassword}"
      ];
    };
    # Seed once so password resets survive restarts. The live file is authoritative after that.
    preStart = ''
      database=/var/lib/authelia-homelab/users_database.yml
      if [ ! -e "$database" ]; then
        install -m 0600 "$CREDENTIALS_DIRECTORY/users_database.yml" "$database"
      fi
    '';
  };
}
