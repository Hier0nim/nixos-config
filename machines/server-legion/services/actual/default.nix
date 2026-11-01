{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = config.services.homelabIngress.domain;
  clientFiles = config.clan.core.vars.generators.actual-oidc.files;
  automationPassword = config.clan.core.vars.generators.actual-automation.files.password.path;
  # Only root automation can use 3100; only root/Caddy can reach the backend.
  guard = "-d 127.0.0.1/32 -p tcp -m multiport --dports 3100,3101 -j actual-local";
in
{
  imports = [ ./enable-actual.nix ];

  clan.core.vars.generators = {
    actual-automation = {
      files.password = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      prompts.password = {
        description = "Existing Actual automation password, copied without rotation";
        type = "hidden";
      };
      runtimeInputs = [ pkgs.coreutils ];
      script = ''
        test -s "$prompts/password"
        install -m 0400 "$prompts/password" "$out/password"
      '';
    };
    actual-oidc = {
      files = lib.genAttrs [ "client-secret" "client-hash" ] (_: {
        owner = "root";
        group = "root";
        mode = "0400";
      });
      runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.argon2-cffi ])) ];
      script = "python3 ${../identity/generate-oidc-client.py}";
    };
  };

  services = {
    authelia.instances.homelab.settings.identity_providers.oidc = {
      authorization_policies.actual = {
        default_policy = "deny";
        rules = [
          {
            policy = "one_factor";
            # The MFA exception still requires finance membership.
            subject = [
              [
                "user:sarcia"
                "group:finance"
              ]
            ];
          }
          {
            policy = "two_factor";
            subject = "group:finance";
          }
        ];
      };
      clients = [
        {
          client_id = "actual";
          client_name = "Actual";
          client_secret = ''{{ mustEnv "CREDENTIALS_DIRECTORY" | printf "%s/actual-client-hash" | secret }}'';
          public = false;
          authorization_policy = "actual";
          consent_mode = "implicit";
          require_pkce = true;
          pkce_challenge_method = "S256";
          redirect_uris = [ "https://kasa.${domain}/openid/callback" ];
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
    actual = {
      enable = true;
      openFirewall = false;
      settings = {
        hostname = "127.0.0.1";
        port = 3101;
        dataDir = "/var/lib/actual";
        loginMethod = "header";
        allowedLoginMethods = [
          "openid"
          "header"
        ];
        enforceOpenId = true;
        userCreationMode = "manual";
        token_expiration = "openid-provider";
        trustedAuthProxies = [ "127.0.0.1/32" ];
        openId = {
          discoveryURL = "https://auth.${domain}";
          client_id = "actual";
          server_hostname = "https://kasa.${domain}";
        };
      };
    };

    caddy = {
      virtualHosts = {
        "http://127.0.0.1:3100" = {
          logFormat = null;
          listenAddresses = [ "127.0.0.1" ];
          extraConfig = ''
            reverse_proxy 127.0.0.1:3101 {
              header_up X-Actual-Password "{file./run/credentials/caddy.service/actual-automation-password}"
            }
          '';
        };
        "kasa.${domain}".extraConfig = lib.mkForce ''
          reverse_proxy 127.0.0.1:3101 {
            header_up -X-Actual-Password
          }
        '';
      };
    };
  };
  systemd.services = {
    authelia-homelab.serviceConfig.LoadCredential = [
      "actual-client-hash:${clientFiles.client-hash.path}"
    ];
    actual = {
      after = [
        "caddy.service"
        "authelia-homelab.service"
      ];
      environment.ACTUAL_OPENID_CLIENT_SECRET_FILE = "%d/oidc-client-secret";
      # The upstream helper enables once, revokes legacy sessions, then becomes a no-op.
      preStart = lib.mkAfter ''
        ${pkgs.nodejs_24}/bin/node ${config.services.actual.package}/lib/actual/packages/sync-server/scripts/enable-openid.js
      '';
      serviceConfig = {
        LoadCredential = [ "oidc-client-secret:${clientFiles.client-secret.path}" ];
        # The native request logger includes authorization codes in callback query strings.
        StandardOutput = "null";
      };
    };
    caddy = {
      after = [ "actual-local-guard.service" ];
      requires = [ "actual-local-guard.service" ];
      serviceConfig = {
        LoadCredential = [ "actual-automation-password:${automationPassword}" ];
      };
    };

    # A separate unit removes the rules on rollback; firewall reload does not run old cleanup hooks.
    actual-local-guard = {
      description = "Restrict Actual's private listeners to their local callers";
      wantedBy = [ "multi-user.target" ];
      after = [ "firewall.service" ];
      before = [ "caddy.service" ];
      path = [ pkgs.iptables ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        iptables -N actual-local 2>/dev/null || true
        iptables -F actual-local
        iptables -A actual-local -m owner --uid-owner 0 -j RETURN
        iptables -A actual-local -p tcp --dport 3101 -m owner --uid-owner caddy -j RETURN
        iptables -A actual-local -p tcp -j REJECT --reject-with tcp-reset
        iptables -C OUTPUT ${guard} 2>/dev/null || iptables -I OUTPUT 1 ${guard}
      '';
      preStop = ''
        while iptables -D OUTPUT ${guard} 2>/dev/null; do :; done
        iptables -F actual-local 2>/dev/null || true
        iptables -X actual-local 2>/dev/null || true
      '';
    };
  };
}
