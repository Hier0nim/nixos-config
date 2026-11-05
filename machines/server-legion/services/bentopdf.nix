{ config, lib, ... }:
let
  cfg = config.services.bentopdf;
in
{
  services.bentopdf = {
    enable = lib.mkDefault true;
    # The native module serves the packaged simple-mode build on a private listener.
    domain = "http://127.0.0.1:8085";
    caddy = {
      enable = true;
      virtualHost = {
        listenAddresses = [ "127.0.0.1" ];
        logFormat = null;
        extraConfig = ''
          header Cross-Origin-Opener-Policy same-origin
          header Cross-Origin-Embedder-Policy require-corp
        '';
      };
    };
  };
  services.homelabIngress.services.pdf = lib.mkIf cfg.enable {
    upstream = "http://127.0.0.1:8085";
    transport = "direct";
    auth = "proxy";
    group = "household";
    extraProxyConfig = "header_up Host 127.0.0.1:8085";
  };
}
