{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  hostName = config.networking.hostName;
  secretsFile = "${config.custom.repoPath}/secrets/${hostName}/beszel.yaml";
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.admin.enable && cfg.services.beszel.enable) {
    homelab.services.beszel = {
      expose.enable = lib.mkDefault true;
      # Beszel has its own PocketBase auth - disable Caddy basicAuth
      auth.group = null;
    };

    sops.secrets = {
      beszel_admin_email = {
        sopsFile = secretsFile;
        key = "beszel_admin_email";
        owner = "root";
        group = "keys";
        mode = "0440";
      };
      beszel_admin_password = {
        sopsFile = secretsFile;
        key = "beszel_admin_password";
        owner = "root";
        group = "keys";
        mode = "0440";
      };
      beszel_agent_key = lib.mkIf config.services.beszel.agent.enable {
        sopsFile = secretsFile;
        key = "beszel_agent_key";
        owner = "root";
        group = "keys";
        mode = "0440";
      };
      beszel_agent_token = lib.mkIf config.services.beszel.agent.enable {
        sopsFile = secretsFile;
        key = "beszel_agent_token";
        owner = "root";
        group = "keys";
        mode = "0440";
      };
    };

    sops.templates = {
      "beszel-hub.env" = {
        owner = "root";
        group = "keys";
        mode = "0440";
        content = ''
          USER_EMAIL=${config.sops.placeholder.beszel_admin_email}
          USER_PASSWORD=${config.sops.placeholder.beszel_admin_password}
        '';
      };
      "beszel-agent.env" = lib.mkIf config.services.beszel.agent.enable {
        owner = "root";
        group = "keys";
        mode = "0440";
        content = ''
          KEY=${config.sops.placeholder.beszel_agent_key}
          TOKEN=${config.sops.placeholder.beszel_agent_token}
        '';
      };
    };

    # Beszel hub - the web dashboard
    services.beszel.hub = {
      enable = true;
      host = "127.0.0.1";
      port = 8090;
      environment = {
        APP_URL = "https://monitor.${cfg.domain}";
      };
      environmentFile = config.sops.templates."beszel-hub.env".path;
    };

    # Beszel agent - disabled until the hub public key and universal token
    # are generated in the UI and stored in secrets/${hostName}/beszel.yaml.
    services.beszel.agent = {
      enable = lib.mkDefault false;
      smartmon.enable = true;
      environment = {
        HUB_URL = "http://127.0.0.1:8090";
        SYSTEM_NAME = hostName;
      };
      environmentFile =
        lib.mkIf config.services.beszel.agent.enable
          config.sops.templates."beszel-agent.env".path;
    };
  };
}
