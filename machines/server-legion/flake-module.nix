{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      machine = inputs.self.nixosConfigurations.server-legion;
      inherit (machine) config;
      openDesign = import ./services/open-design/image.nix {
        inherit pkgs;
        builder = inputs.nix2container.packages.${system}.nix2container;
      };
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
        open-design-image = openDesign.image;
        open-design-smoke = pkgs.writeShellApplication {
          name = "open-design-smoke";
          runtimeInputs = [
            pkgs.docker
            pkgs.podman
            pkgs.coreutils
          ];
          text =
            builtins.replaceStrings
              [ "@dockerLoader@" "@podmanLoader@" "@imageRef@" ]
              [
                "${openDesign.image.copyToDockerDaemon}/bin/copy-to-docker-daemon"
                "${openDesign.image.copyToPodman}/bin/copy-to-podman"
                "${openDesign.image.imageName}:${openDesign.image.imageTag}"
              ]
              (builtins.readFile ./services/open-design/smoke-test.sh);
        };
      };
      checks = import ./checks {
        inherit pkgs config;
        dns = dns.check;
        # Check the enabled module without changing Legion's live configuration.
        openDesignConfig =
          (machine.extendModules {
            modules = [ { services.open-design.enable = true; } ];
          }).config;
      };
    };
}
