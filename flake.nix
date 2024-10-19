{
  description = "Hier0nim's NixOS Configuration.";

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixvim,
      ...
    }@inputs:
    let
      settings = import (./. + "/settings.nix") { inherit pkgs; };
      pkgs = import nixpkgs { system = settings.system; };
    in
    {
      nixosConfigurations = {
        ${settings.hostname} = nixpkgs.lib.nixosSystem {
          modules = [
            (./. + "/profiles" + ("/" + settings.profile) + "/configuration.nix")
          ];
          specialArgs = {
            inherit inputs;
            inherit settings;
          };
        };
      };

      homeConfigurations = {
        ${settings.username} = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${settings.system};
          modules = [
            (./. + "/profiles" + ("/" + settings.profile) + "/home.nix")
          ];
          extraSpecialArgs = {
            inherit inputs;
            inherit settings;
          };
        };
      };
    };

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm.url = "github:wez/wezterm/main?dir=nix";

    catppuccin.url = "github:catppuccin/nix";

    nixvim.url = "github:Hier0nim/nixvim-config";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
