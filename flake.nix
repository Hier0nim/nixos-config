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

      # ========== Extend lib with lib.custom ==========
      # NOTE: This approach allows lib.custom to propagate into hm
      # see: https://github.com/nix-community/home-manager/pull/3454
      baseLib = nixpkgs.lib;
      lib = baseLib.extend (self: super: { custom = import ./lib { lib = self; }; });

    in
    {
      # ========= Host Configurations =========
      nixosConfigurations =
        let
          hosts = import ./hosts { inherit inputs; };
        in
        lib.mapAttrs (
          _name: host:
          lib.custom.mkHost {
            inherit inputs outputs self;
            inherit (host) nixpkgs system modules;
            specialArgs = host.specialArgs or { };
          }
        ) hosts;

      # ========= Formatting =========
      # Nix formatter available through 'nix fmt' https://github.com/NixOS/nixfmt
      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixfmt
      );

      # Pre-commit checks + host build checks
      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        import ./checks.nix {
          inherit inputs system pkgs;
          inherit (self) nixosConfigurations;
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
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    nixos-hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-stable = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    nixflix = {
      url = "github:kiriwalawren/nixflix/17738063b822d002194dc3c213f119600d2d6fb8";
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

    danksearch = {
      url = "github:AvengeMedia/danksearch";
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

    open-design.url = "github:nexu-io/open-design";
  };
}
