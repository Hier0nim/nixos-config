{
  config,
  pkgs,
  ...
}:
let
  files = config.clan.core.vars.generators.beszel.files;
  hostName = config.networking.hostName;
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

  services.beszel = {
    hub = {
      enable = true;
      host = "127.0.0.1";
      port = 8090;
      environment = {
        APP_URL = "https://monitor.pieczarkowo.me";
      };
      environmentFile = files."hub.env".path;
    };
    agent = {
      enable = true;
      smartmon.enable = true;
      environment = {
        HUB_URL = "http://127.0.0.1:8090";
        SYSTEM_NAME = hostName;
      };
      environmentFile = files."agent.env".path;
    };
  };
}
