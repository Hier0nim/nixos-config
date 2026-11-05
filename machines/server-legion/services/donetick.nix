{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.donetick;
  domain = config.services.homelabIngress.domain;
  settings = (pkgs.formats.yaml { }).generate "donetick.yaml" {
    name = "selfhosted";
    is_done_tick_dot_com = false;
    is_user_creation_disabled = true;
    single_circle_instance = true;
    disable_password_auth = true;
    database = {
      type = "sqlite";
      migration = true;
    };
    # Declare secret keys so Viper binds their runtime environment overrides.
    jwt.secret = "";
    server = {
      port = 2021;
      serve_frontend = true;
      serve_swagger = false;
      public_host = "https://todo.${domain}";
      cors_allow_origins = [
        "https://todo.${domain}"
        "https://localhost"
        "http://localhost"
        "capacitor://localhost"
      ];
    };
    oauth2 = {
      client_id = "donetick";
      client_secret = "";
      redirect_url = "https://todo.${domain}/auth/oauth2";
      pkce = true;
      scopes = [
        "openid"
        "profile"
        "email"
        "groups"
      ];
      admin_groups = [ "infra-admin" ];
      manager_groups = [ "household" ];
      auth_url = "https://auth.${domain}/api/oidc/authorization";
      token_url = "https://auth.${domain}/api/oidc/token";
      user_info_url = "https://auth.${domain}/api/oidc/userinfo";
      name = "Authelia";
    };
    scheduler_jobs = {
      due_job = "30m";
      overdue_job = "3h";
      pre_due_job = "3h";
    };
    email.log_raw_url = false;
    realtime = {
      enabled = true;
      sse_enabled = true;
      allowed_origins = [
        "https://todo.${domain}"
        "https://localhost"
        "capacitor://localhost"
      ];
    };
    bridge.enabled = false;
  };
in
{
  options.services.donetick.enable = lib.mkEnableOption "the household Donetick container";
  config = lib.mkMerge [
    { services.donetick.enable = lib.mkDefault true; }
    (lib.mkIf cfg.enable {
      users.groups.donetick.gid = 1003;
      users.users.donetick = {
        uid = 1003;
        group = "donetick";
        isSystemUser = true;
      };
      systemd.tmpfiles.rules = [ "d /var/lib/donetick 0700 donetick donetick - -" ];
      virtualisation.oci-containers.containers.donetick = {
        image = "docker.io/donetick/donetick:v0.1.86@sha256:66253a32a8e8ed8c49c49418b43abe1181db23e07defe97748d2cb7508c487cd";
        user = "1003:1003";
        ports = [ "127.0.0.1:2021:2021" ];
        environment = {
          DT_ENV = "selfhosted";
          TZ = config.time.timeZone;
          DT_SQLITE_PATH = "/donetick-data/donetick.db";
        };
        environmentFiles = [ config.clan.core.vars.generators.donetick-oidc.files.environment.path ];
        volumes = [
          "${settings}:/config/selfhosted.yaml:ro"
          "/var/lib/donetick:/donetick-data"
        ];
        # Upstream OAuth error logs can contain authorization-code fragments.
        extraOptions = [
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges:true"
          "--log-driver=none"
          # OIDC must use the public tunnel, not the guarded LAN origin.
          "--dns=1.1.1.1"
          "--dns=1.0.0.1"
        ];
      };
      services.homelabIngress.services.todo = {
        upstream = "http://127.0.0.1:2021";
        transport = "direct";
        auth = "native";
      };
    })
  ];
}
