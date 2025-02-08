{
  description = "Hier0nim's NixOS Configuration.";

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nixos-hardware,
      home-manager,
      nixvim,
      ...
    }@inputs:
    let
      settings = import (./. + "/settings.nix") { inherit pkgs; };
      pkgs = import nixpkgs {
        system = settings.system;
        overlays = builtins.attrValues (import ./overlays);
      };

      pkgs-stable = import nixpkgs-stable {
        system = settings.system;
      };
    in
    {
      nixosConfigurations = {
        ${settings.hostname} = nixpkgs.lib.nixosSystem {
          modules = [
            (./. + "/profiles" + ("/" + settings.profile) + "/configuration.nix")
            nixos-hardware.nixosModules.asus-zephyrus-ga402x-nvidia
          ];
          specialArgs = {
            inherit inputs settings pkgs-stable;
            nixpkgs.pkgs = nixpkgs.nixosModules.pkgsReadOnly;
          };
        };
      };

      homeConfigurations = {
        ${settings.username} = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs;
          modules = [
            (./. + "/profiles" + ("/" + settings.profile) + "/home.nix")
          ];
          extraSpecialArgs = {
            inherit inputs settings pkgs-stable;
          };
        };
      };
    };

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-24.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm.url = "github:wez/wezterm/main?dir=nix";

    catppuccin.url = "github:catppuccin/nix";

    nixvim.url = "github:Hier0nim/nvim";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nbfc-linux = {
      url = "github:nbfc-linux/nbfc-linux";
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
  };
}
