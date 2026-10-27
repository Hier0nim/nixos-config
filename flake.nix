{
  description = "Hieronim's Clan configuration";

  inputs = {
    clan-core = {
      url = "https://git.clan.lol/clan/clan-core/archive/26.05.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.follows = "clan-core/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arkenfox-userjs = {
      url = "github:arkenfox/user.js";
      flake = false;
    };
    nvim = {
      url = "github:Hier0nim/nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    creamlinux-installer = {
      url = "github:Novattz/creamlinux-installer";
      flake = false;
    };
    pi-config = {
      url = "git+ssh://git@github.com/Hier0nim/dot_pi.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    umbriel = {
      url = "github:noctalia-dev/umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    asus-px-keyboard-tool = {
      url = "github:a-chaudhari/asus-px-keyboard-tool";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        inputs.clan-core.flakeModules.default
        inputs.git-hooks.flakeModule
      ];

      flake.clan.imports = [ ./clan.nix ];

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          formatter = pkgs.nixfmt;
          pre-commit.settings.hooks = {
            nixfmt.enable = true;
            deadnix.enable = true;
            statix.enable = true;
          };

          devShells.default = pkgs.mkShell {
            shellHook = config.pre-commit.shellHook;
            packages = config.pre-commit.settings.enabledPackages ++ [
              inputs.clan-core.packages.${system}.clan-cli
            ];
          };
        };
    };
}
