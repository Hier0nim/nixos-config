{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;

  jellyfinFqdn = "${cfg.services.jellyfin.subdomain}.${cfg.domain}";
  immichFqdn = "${cfg.services.immich.subdomain}.${cfg.domain}";
  copypartyFqdn = "${cfg.services.copyparty.subdomain}.${cfg.domain}";
  jellyseerrFqdn = "${cfg.services.jellyseerr.subdomain}.${cfg.domain}";
  audiobookshelfFqdn = "${cfg.services.audiobookshelf.subdomain}.${cfg.domain}";
in
{
  config = lib.mkIf (cfg.enable && cfg.proxy.enable) {
    services.caddy.enable = true;

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.caddy.virtualHosts = {
      "${jellyfinFqdn}" = {
        extraConfig = ''
          reverse_proxy http://127.0.0.1:8096
        '';
      };
      "${immichFqdn}" = {
        extraConfig = ''
          reverse_proxy http://127.0.0.1:2283
        '';
      };
      "${copypartyFqdn}" = {
        extraConfig = ''
          reverse_proxy http://127.0.0.1:3923
        '';
      };
      "${jellyseerrFqdn}" = {
        extraConfig = ''
          reverse_proxy http://127.0.0.1:5055
        '';
      };
      "${audiobookshelfFqdn}" = {
        extraConfig = ''
          reverse_proxy http://127.0.0.1:9292
        '';
      };
    };
  };
}
