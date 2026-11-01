# ingress is the evaluated service registry; directTarget is Legion's public DDNS hostname.
{ ingress, directTarget }:
let
  inherit (ingress)
    domain
    services
    enableTunnel
    tunnelId
    ;
  validName = name: builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" name != null;
  validTunnelId =
    tunnelId != null
    && builtins.match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" tunnelId != null
    && tunnelId != "00000000-0000-0000-0000-000000000000";
in
assert domain == "pieczarkowo.me";
assert builtins.match "[a-z0-9]([a-z0-9.-]*[a-z0-9])?" directTarget != null;
assert builtins.all (name: validName name && name != "ha") (builtins.attrNames services);
assert !enableTunnel || validTunnelId;
builtins.mapAttrs (
  name: service:
  let
    tunneled = enableTunnel && service.transport == "tunnel";
  in
  {
    name = "${name}.${domain}";
    type = "CNAME";
    content = if tunneled then "${tunnelId}.cfargotunnel.com" else directTarget;
    proxied = tunneled;
    ttl = 1;
  }
) services
