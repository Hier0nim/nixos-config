{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      config = inputs.self.nixosConfigurations.server-legion.config;
      dns = import ./dns {
        inherit pkgs;
        inherit (inputs) terranix;
        clan = inputs.clan-core.packages.${system}.clan-cli;
        ingress = config.services.homelabIngress;
      };
    in
    {
      packages = {
        legion-dns = dns.command;
        legion-dns-config = dns.configuration;
        legion-dns-tools = dns.tools;
      };
      checks = import ./checks {
        inherit pkgs config;
        dns = dns.check;
      };
    };
}
