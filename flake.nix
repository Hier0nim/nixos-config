{
  description = "NixOS and Home Manager Flake";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
      ];

      customLib = import ./lib {
        inherit (nixpkgs) lib;
      };

    in
    {
      # ========= Host Configurations =========
      nixosConfigurations =
        let
          hosts = import ./hosts { inherit inputs; };
        in
        nixpkgs.lib.mapAttrs (
          _name: host:
          customLib.mkHost {
            inherit
              customLib
              inputs
              outputs
              self
              ;
            inherit (host) nixpkgs system modules;
            specialArgs = host.specialArgs or { };
          }
        ) hosts;

      # ========= Formatting =========
      # Nix formatter available through 'nix fmt' https://github.com/NixOS/nixfmt
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Pre-commit checks + host build checks
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./checks.nix {
          inherit inputs system pkgs;
          inherit (self) nixosConfigurations;
        }
      );

      # ========= Utility Apps =========
      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          update-plugin-hashes = {
            type = "app";
            program =
              let
                app = pkgs.writeShellApplication {
                  name = "update-plugin-hashes";
                  runtimeInputs = with pkgs; [
                    curl
                    nix
                    gnused
                  ];
                  text = builtins.readFile ./scripts/update-plugin-hashes.sh;
                };
              in
              "${app}/bin/update-plugin-hashes";
          };
        }
      );

      # ========= DevShell =========
      # Custom shell for bootstrapping on new hosts, modifying nix-config, and secrets management
      devShells = forAllSystems (
        system:
        import ./shell.nix {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
          checks = self.checks.${system};
        }
      );

    };

  inputs = {
    # ========= Official NixOS, and HM Package Sources =========
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    nixos-hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-stable = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    nixflix = {
      url = "github:kiriwalawren/nixflix/2aa1d080f760584d1205575f730525349f5c38cb";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    copyparty = {
      url = "github:9001/copyparty";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # ========= Utilities =========
    # Declarative partitioning and formatting
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    # Secrets management.
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pre-commit
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-float-sticky = {
      url = "github:probeldev/niri-float-sticky";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Addons for firefox
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardened firefox
    arkenfox-userjs = {
      url = "github:arkenfox/user.js";
      flake = false;
    };

    asus-px-keyboard-tool.url = "github:a-chaudhari/asus-px-keyboard-tool";

    nixCats = {
      url = "github:Hier0nim/nvim";
    };

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    pi-config.url = "git+ssh://git@github.com/Hier0nim/dot_pi.git";

    open-design.url = "github:nexu-io/open-design/d64695937efd2c4f8ff8f07c11e5a7030e32c39a";

    creamlinux-installer = {
      url = "github:Novattz/creamlinux-installer/7c16b63b41f984a1f480fa14ce78da4cc4869a66";
      flake = false;
    };

    # Pre-built nix-index databases for comma
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
