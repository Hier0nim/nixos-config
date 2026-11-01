{ pkgs, config }:
let
  forgejo = config.services.forgejo;
  oidc = config.services.authelia.instances.homelab.settings.identity_providers.oidc;
  client = builtins.head (builtins.filter (client: client.client_id == "forgejo") oidc.clients);
in
assert forgejo.package.version == pkgs.forgejo-lts.version;
assert forgejo.settings.service.DISABLE_REGISTRATION;
assert !forgejo.settings.oauth2_client.ENABLE_AUTO_REGISTRATION;
assert forgejo.settings.oauth2_client.ACCOUNT_LINKING == "login";
assert !forgejo.settings.oauth2_client.UPDATE_AVATAR;
assert forgejo.settings.log.DISABLE_ROUTER_LOG && !forgejo.settings.log.ENABLE_ACCESS_LOG;
assert client.authorization_policy == "forgejo";
assert client.require_pkce && client.pkce_challenge_method == "S256";
assert client.token_endpoint_auth_method == "client_secret_basic";
assert client.redirect_uris == [ "https://git.pieczarkowo.me/user/oauth2/authelia/callback" ];
assert
  oidc.authorization_policies.forgejo == {
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
pkgs.runCommand "legion-forgejo-contracts"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.openssl
      pkgs.git
    ];
    FORGEJO_PACKAGE = forgejo.package;
    FORGEJO_DATA = forgejo.package.data;
    FORGEJO_PRESTART = pkgs.writeText "forgejo-prestart" config.systemd.services.forgejo.preStart;
  }
  ''
    python3 ${./test.py}
    touch "$out"
  ''
