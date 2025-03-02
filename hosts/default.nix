{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations = let
    inherit (inputs.nixpkgs) lib;
    inherit (lib) nixosSystem;
    inherit (lib.attrsets) recursiveUpdate;
    inherit (lib.lists) concatLists flatten singleton;

    # Core modules from external inputs
    nixosModules = [
      inputs.disko.nixosModules.default
      inputs.home-manager.nixosModules.default
    ];

    # Common configuration shared across all systems
    sharedConfig = [
      ./common/core
    ];

    # Function to create a NixOS configuration for a specific hostname and system
    # Arguments:
    #  - hostname: The hostname of the system
    #  - system: The system architecture
    #  - modules (optional): Additional modules to include
    #  - specialArgs (optional): Additional special arguments passed to the system
    mkNixosSystem = {
      hostname,
      system,
      ...
    } @ args:
      nixosSystem {
        modules =
          concatLists [
            (singleton {
              networking.hostName = args.hostname;
              nixpkgs.hostPlatform = args.system;
            })

            (flatten (concatLists [
              (singleton ./${args.hostname})
              (args.modules or [])
            ]))
          ]
          ++ sharedConfig;

        specialArgs = recursiveUpdate {
          inherit inputs self;
          lib = inputs.nixpkgs.lib.extend (
            _: _: {custom = import ../lib {inherit (inputs.nixpkgs) lib;};}
          );
        } (args.specialArgs or {});
      };
  in {
    # Asus Zephyrus G14 (GA402 Nvidia)
    zephyrus-g14 = mkNixosSystem {
      hostname = "zephyrus-g14";
      system = "x86_64-linux";
      modules = [
        nixosModules
        inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402x-nvidia
      ];
    };
  };
}
