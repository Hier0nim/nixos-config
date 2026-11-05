{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mealie;
  files = config.clan.core.vars.generators.mealie-oidc.files;
in
{
  services.mealie = {
    enable = lib.mkDefault true;
    listenAddress = "127.0.0.1";
    port = 9000;
    credentialsFile = lib.mkIf cfg.enable files.environment.path;
    settings = {
      BASE_URL = "https://przepisy.${config.services.homelabIngress.domain}";
      TZ = config.time.timeZone;
      DB_ENGINE = "sqlite";
      ALLOW_SIGNUP = "false";
      ALLOW_PASSWORD_LOGIN = "false";
      DEFAULT_GROUP = "Home";
      DEFAULT_HOUSEHOLD = "Family";
      OIDC_AUTH_ENABLED = "true";
      OIDC_SIGNUP_ENABLED = "true";
      OIDC_REQUIRES_EMAIL_VERIFICATION = "true";
      OIDC_CLIENT_ID = "mealie";
      OIDC_CONFIGURATION_URL = "https://auth.${config.services.homelabIngress.domain}/.well-known/openid-configuration";
      OIDC_PROVIDER_NAME = "Authelia";
      OIDC_USER_GROUP = "household";
      OIDC_ADMIN_GROUP = "infra-admin";
    };
  };
  systemd.services.mealie = lib.mkIf cfg.enable {
    serviceConfig.LoadCredential = [
      "app-secret:${files.app-secret.path}"
      "session-secret:${files.session-secret.path}"
    ];
    serviceConfig.ExecStartPre = lib.mkBefore [
      (pkgs.writeShellScript "mealie-secrets" ''
        if [ ! -s "$STATE_DIRECTORY/.secret" ]; then
          ${pkgs.coreutils}/bin/install -m 0600 "$CREDENTIALS_DIRECTORY/app-secret" "$STATE_DIRECTORY/.secret"
        fi
        if [ ! -s "$STATE_DIRECTORY/.session_secret" ]; then
          ${pkgs.coreutils}/bin/install -m 0600 "$CREDENTIALS_DIRECTORY/session-secret" "$STATE_DIRECTORY/.session_secret"
        fi
      '')
    ];
  };
  services.homelabIngress.services.przepisy = lib.mkIf cfg.enable {
    upstream = "http://127.0.0.1:9000";
    transport = "direct";
    auth = "native";
  };
}
