{ pkgs, config }:
let
  ingress = config.services.homelabIngress;
  # Copyparty's browser/native routes have their own native fixture.
  controls = pkgs.lib.filterAttrs (
    name: service: service.auth == "proxy" && name != "pliki"
  ) ingress.services;
  routes = pkgs.writeText "ingress-test-routes.json" (
    builtins.toJSON (
      pkgs.lib.mapAttrs (_: service: {
        inherit (service) upstream integrationApiBypass pathPrefix;
        route = config.services.caddy.virtualHosts.${service.hostname}.extraConfig;
      }) controls
    )
  );
in
assert pkgs.lib.all (host: host.logFormat == null) (
  builtins.attrValues config.services.caddy.virtualHosts
);
pkgs.runCommand "legion-ingress-contracts"
  {
    nativeBuildInputs = [
      config.services.caddy.package
      pkgs.python3
    ];
    INGRESS_ROUTES = routes;
    CADDY_LOG_FORMAT = config.services.caddy.logFormat;
  }
  ''
    export HOME="$TMPDIR"
    python3 ${./ingress.py}
    touch "$out"
  ''
