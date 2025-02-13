{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations =
    let
      inherit (inputs.nixpkgs) lib;
      inherit (lib) nixosSystem;
      inherit (lib.attrsets) recursiveUpdate;
      inherit (lib.lists) concatLists flatten singleton;

      # Core modules from external inputs
      nixosModules = [
        inputs.disko.nixosModules.default
        inputs.home-manager.nixosModules.default
      ];

      # Path to the home-manager module directory
      homeModules = self + /home;

      # Common configuration shared across all systems
      sharedConfig = [
        ./config/nix
        ./config/programs
        ./config/security
        ./config/services
        ./config/shell
        ./config/system
        ./config/input-devices
      ];

      # Function to create a NixOS configuration for a specific hostname and system
      # Arguments:
      #  - hostname: The hostname of the system
      #  - system: The system architecture
      #  - modules (optional): Additional modules to include
      #  - specialArgs (optional): Additional special arguments passed to the system
      mkNixosSystem =
        {
          hostname,
          system,
          ...
        }@args:
        nixosSystem {
          modules =
            concatLists [
              (singleton {
                networking.hostName = args.hostname;
                nixpkgs.hostPlatform = args.system;
              })

              (flatten (concatLists [
                (singleton ./${args.hostname})
                (args.modules or [ ])
              ]))
            ]
            ++ sharedConfig;

          specialArgs = recursiveUpdate {
            inherit inputs self;
          } (args.specialArgs or { });
        };
    in
    {
      # Asus Zephyrus G14 (GA402 Nvidia)
      zephyrus-g14 = mkNixosSystem {
        hostname = "zephyrus-g14";
        system = "x86_64-linux";
        modules = [
          nixosModules
          homeModules
          inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402x-nvidia
        ];
      };
    };
}
