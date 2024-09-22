{
  description = "Hier0nim's NixOS Configuration.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    wezterm = {
      url = "github:wez/wezterm/main?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (import ./system/options.nix) hostName system;
      inherit (import ./home/options.nix) userName;
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."${userName}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs;
        };
        modules = [ ./home/home.nix ];
      };

      nixosConfigurations."${hostName}" = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [ ./system/configuration.nix ];
      };
    };
}
