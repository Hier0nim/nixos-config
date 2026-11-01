{ pkgs, config }:
let
  ingress = config.services.homelabIngress;
  # Copyparty's browser/native routes have their own native fixture.
  controls = pkgs.lib.filterAttrs (
    name: service: service.auth == "proxy" && name != "pliki"
  ) ingress.services;
  routes = pkgs.writeText "ingress-test-routes.json" (
    builtins.toJSON (
      pkgs.lib.mapAttrs (name: service: {
        inherit (service) upstream integrationApiBypass pathPrefix;
        route = config.services.caddy.virtualHosts."${name}.${ingress.domain}".extraConfig;
      }) controls
    )
  );
in
assert pkgs.lib.all (host: host.logFormat == null) (
  builtins.attrValues config.services.caddy.virtualHosts
);
assert pkgs.lib.all
  (
    family:
    let
      address =
        if family == "iptables" then
          config.vpnNamespaces.wg.namespaceAddress
        else
          config.vpnNamespaces.wg.namespaceAddressIPv6;
      rule = "-d ${address} -p tcp -m multiport --dports 8989,8990,7878,9696 -j REJECT --reject-with tcp-reset";
    in
    pkgs.lib.hasInfix "${family} -I FORWARD 1 ${rule}" config.networking.firewall.extraCommands
    && pkgs.lib.hasInfix "${family} -D FORWARD ${rule}" config.networking.firewall.extraStopCommands
  )
  [
    "iptables"
    "ip6tables"
  ];
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
