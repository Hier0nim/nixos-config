{
  pkgs,
  config,
  dns,
}:
{
  legion-dns = dns;
  legion-ingress = import ./ingress.nix { inherit pkgs config; };
  legion-oidc = import ../services/identity/check.nix { inherit pkgs config; };
  legion-beszel = import ../services/beszel/check.nix { inherit pkgs config; };
  legion-copyparty = import ../services/copyparty/check.nix { inherit pkgs config; };
  legion-forgejo = import ../services/forgejo/check.nix { inherit pkgs config; };
}
