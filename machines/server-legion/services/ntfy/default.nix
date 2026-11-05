{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ntfy-sh;
  files = config.clan.core.vars.generators.ntfy.files;
in
{
  services.ntfy-sh = {
    enable = lib.mkDefault true;
    environmentFile = files."server.env".path;
    settings = {
      base-url = "https://ntfy.${config.services.homelabIngress.domain}";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      auth-default-access = "deny-all";
      auth-access = [
        "hieronim:infra:ro"
        "gatus:infra:wo"
      ];
      enable-login = true;
      enable-signup = false;
      enable-reservations = false;
      cache-duration = "168h";
      # Android connects directly. No cloud relay or uploaded attachments.
      attachment-cache-dir = "";
      upstream-base-url = "";
    };
  };

  clan.core.vars.generators.ntfy = {
    files = lib.genAttrs [ "server.env" "hieronim-password" "hieronim-token" "gatus-token" ] (_: {
      deploy = cfg.enable;
      owner = "root";
      group = "root";
      mode = "0400";
    });
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: [ ps.bcrypt ]))
      cfg.package
    ];
    script = ''
      python3 ${./generate-secrets.py}
    '';
  };

  services.homelabIngress.services.ntfy = lib.mkIf cfg.enable {
    upstream = "http://127.0.0.1:2586";
    transport = "direct";
    auth = "native";
  };
}
