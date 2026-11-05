{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = config.services.homelabIngress.domain;
  apps = lib.filterAttrs (_: app: app.enable) {
    paperless = {
      enable = config.services.paperless.enable;
      redirects = [ "https://dokumenty.${domain}/accounts/oidc/authelia/login/callback/" ];
      pkce = false;
    };
    mealie = {
      enable = config.services.mealie.enable;
      redirects = [ "https://przepisy.${domain}/login" ];
      pkce = true;
    };
    donetick = {
      enable = config.services.donetick.enable;
      redirects = [
        "https://todo.${domain}/auth/oauth2"
        "donetick://auth/oauth2"
      ];
      pkce = true;
    };
  };
  vars = name: config.clan.core.vars.generators."${name}-oidc".files;
in
{
  clan.core.vars.generators = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${name}-oidc" {
      files = {
        client-secret = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
        client-hash = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
        environment = {
          owner = if name == "paperless" then "paperless" else "root";
          group = if name == "paperless" then "paperless" else "root";
          mode = "0400";
        };
      }
      // lib.optionalAttrs (name == "mealie") {
        app-secret = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
        session-secret = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
      };
      runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.argon2-cffi ])) ];
      script = ''
        python3 ${./generate-oidc-client.py}
        python3 ${./generate-app-secrets.py} ${name} ${lib.escapeShellArg domain}
      '';
    }
  ) apps;

  services.authelia.instances.homelab.settings.identity_providers.oidc = {
    authorization_policies.household-apps = {
      default_policy = "deny";
      rules = [
        {
          policy = "one_factor";
          subject = [
            [
              "user:sarcia"
              "group:household"
            ]
          ];
        }
        {
          policy = "two_factor";
          subject = [
            [
              "user:hieronim"
              "group:household"
            ]
          ];
        }
      ];
    };
    clients = lib.mapAttrsToList (name: app: {
      client_id = name;
      client_name = name;
      client_secret = ''{{ mustEnv "CREDENTIALS_DIRECTORY" | printf "%s/${name}-client-hash" | secret }}'';
      public = false;
      authorization_policy = "household-apps";
      consent_mode = "implicit";
      require_pkce = app.pkce;
      redirect_uris = app.redirects;
      scopes = [
        "openid"
        "email"
        "profile"
        "groups"
      ];
      response_types = [ "code" ];
      grant_types = [ "authorization_code" ];
      token_endpoint_auth_method =
        if name == "paperless" then "client_secret_post" else "client_secret_basic";
    }) apps;
  };
  systemd.services.authelia-homelab.serviceConfig.LoadCredential = lib.mapAttrsToList (
    name: _: "${name}-client-hash:${(vars name).client-hash.path}"
  ) apps;
}
