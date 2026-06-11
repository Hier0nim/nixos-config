# Host registry — add new hosts here.
# Each entry becomes a nixosConfiguration generated in flake.nix.
{ inputs }:
let
  # Flake modules shared by all hosts
  commonModules = [
    inputs.determinate.nixosModules.default
    inputs.disko.nixosModules.default
  ];
in
{
  zephyrus-g14 = {
    system = "x86_64-linux";
    inherit (inputs) nixpkgs;
    modules = commonModules ++ [
      inputs.home-manager.nixosModules.default
      inputs.asus-px-keyboard-tool.nixosModules.default
      ./zephyrus-g14
    ];
  };

  server-legion = {
    system = "x86_64-linux";
    nixpkgs = inputs.nixpkgs-stable;
    modules = commonModules ++ [
      inputs.home-manager-stable.nixosModules.default
      inputs.nixflix.nixosModules.default
      inputs.copyparty.nixosModules.default
      ./server-legion
    ];
    # Remap inputs so modules see stable nixpkgs/home-manager under
    # the canonical names, and unstable under nixpkgs-unstable.
    specialArgs = {
      inputs = inputs // {
        nixpkgs-unstable = inputs.nixpkgs;
        nixpkgs = inputs.nixpkgs-stable;
        home-manager = inputs.home-manager-stable;
      };
    };
  };
}
