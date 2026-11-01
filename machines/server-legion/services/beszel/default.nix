{
  config,
  lib,
  pkgs,
  ...
}:
let
  files = config.clan.core.vars.generators.beszel.files;
  domain = config.services.homelabIngress.domain;
  clientFiles = config.clan.core.vars.generators.beszel-oidc.files;
  oidcConfig = pkgs.writeText "beszel-oidc.json" (
    builtins.toJSON {
      origin = "http://127.0.0.1:8090";
      database = "${config.services.beszel.hub.dataDir}/beszel_data/data.db";
      provider = {
        name = "oidc";
        displayName = "Authelia";
        clientId = "beszel";
        authURL = "https://auth.${domain}/api/oidc/authorization";
        tokenURL = "https://auth.${domain}/api/oidc/token";
        userInfoURL = "https://auth.${domain}/api/oidc/userinfo";
        pkce = true;
      };
    }
  );
in
{
  clan.core.vars.generators.beszel = {
    files = {
      "hub.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "agent.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
    prompts = {
      "hub.env" = {
        description = "Beszel hub administrator environment file";
        type = "multiline-hidden";
      };
      "agent.env" = {
        description = "Beszel agent environment file";
        type = "multiline-hidden";
      };
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      install -m 0400 "$prompts/hub.env" "$out/hub.env"
      install -m 0400 "$prompts/agent.env" "$out/agent.env"
    '';
  };

  clan.core.vars.generators.beszel-oidc = {
    files = lib.genAttrs [ "client-secret" "client-hash" ] (_: {
      owner = "root";
      group = "root";
      mode = "0400";
    });
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.argon2-cffi ])) ];
    script = "python3 ${../identity/generate-oidc-client.py}";
  };

  services.authelia.instances.homelab.settings.identity_providers.oidc = {
    authorization_policies.beszel = {
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
        client_id = "beszel";
        client_name = "Beszel";
        client_secret = ''{{ mustEnv "CREDENTIALS_DIRECTORY" | printf "%s/beszel-client-hash" | secret }}'';
        public = false;
        authorization_policy = "beszel";
        consent_mode = "implicit";
        require_pkce = true;
        pkce_challenge_method = "S256";
        redirect_uris = [ "https://monitor.${domain}/api/oauth2-redirect" ];
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
  systemd.services.authelia-homelab.serviceConfig.LoadCredential = [
    "beszel-client-hash:${clientFiles.client-hash.path}"
  ];

  systemd.services.beszel-oidc = {
    description = "Configure the native Beszel OIDC provider";
    wantedBy = [ "multi-user.target" ];
    requires = [ "beszel-hub.service" ];
    after = [ "beszel-hub.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.python3}/bin/python3 ${./beszel-oidc.py} ${oidcConfig}";
      LoadCredential = [
        "hub.env:${files."hub.env".path}"
        "client-secret:${clientFiles.client-secret.path}"
      ];
      User = "root";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  services.beszel = {
    hub = {
      enable = true;
      host = "127.0.0.1";
      port = 8090;
      environment.APP_URL = "https://monitor.${domain}";
      environmentFile = files."hub.env".path;
    };
    agent = {
      enable = true;
      smartmon.enable = true;
      environment = {
        HUB_URL = "http://127.0.0.1:8090";
        SYSTEM_NAME = config.networking.hostName;
      };
      environmentFile = files."agent.env".path;
    };
  };
}
