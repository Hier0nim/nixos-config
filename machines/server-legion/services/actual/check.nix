{ pkgs, config }:
let
  actual = config.services.actual;
  policy =
    config.services.authelia.instances.homelab.settings.identity_providers.oidc.authorization_policies.actual;
in
assert actual.settings.hostname == "127.0.0.1" && actual.settings.port == 3101;
assert actual.settings.loginMethod == "header";
assert
  actual.settings.allowedLoginMethods == [
    "openid"
    "header"
  ];
assert actual.settings.enforceOpenId && actual.settings.userCreationMode == "manual";
assert actual.settings.token_expiration == "openid-provider";
assert policy.default_policy == "deny";
assert
  policy.rules == [
    {
      policy = "one_factor";
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
assert pkgs.lib.hasInfix "header_up -X-Actual-Password"
  config.services.caddy.virtualHosts."kasa.pieczarkowo.me".extraConfig;
assert config.systemd.services.caddy.serviceConfig.RuntimeDirectoryMode == "0700";
assert pkgs.lib.hasInfix "admin unix//run/caddy/admin.sock" config.services.caddy.globalConfig;
assert pkgs.lib.hasInfix "iptables -I OUTPUT 1" config.systemd.services.actual-local-guard.script;
assert pkgs.lib.hasInfix "iptables -X actual-local"
  config.systemd.services.actual-local-guard.preStop;
pkgs.runCommand "legion-actual-contracts"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.openssl
    ];
    ACTUAL_PACKAGE = actual.package;
    NODE_PACKAGE = pkgs.nodejs_24;
    CADDY_PACKAGE = config.services.caddy.package;
  }
  ''
    python3 ${./test.py}
    touch "$out"
  ''
