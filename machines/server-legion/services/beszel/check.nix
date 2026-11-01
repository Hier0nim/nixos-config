{ pkgs, config }:
let
  oidc = config.services.authelia.instances.homelab.settings.identity_providers.oidc;
  client = builtins.head (builtins.filter (client: client.client_id == "beszel") oidc.clients);
in
assert config.services.beszel.hub.environment.APP_URL == "https://monitor.pieczarkowo.me";
assert !(config.services.beszel.hub.environment ? DISABLE_PASSWORD_AUTH);
assert !(config.services.beszel.hub.environment ? TRUSTED_AUTH_HEADER);
assert !(config.services.beszel.hub.environment ? USER_CREATION);
assert client.require_pkce && client.pkce_challenge_method == "S256";
assert client.token_endpoint_auth_method == "client_secret_basic";
assert client.authorization_policy == "beszel";
assert
  client.redirect_uris == [
    "https://monitor.pieczarkowo.me/api/oauth2-redirect"
  ];
assert
  oidc.authorization_policies.beszel == {
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
pkgs.runCommand "legion-beszel-contracts"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.openssl
    ];
    BESZEL_PACKAGE = config.services.beszel.hub.package;
    BESZEL_PROVISIONER = ./beszel-oidc.py;
  }
  ''
    python3 ${./test.py}
    touch "$out"
  ''
