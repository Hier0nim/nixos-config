{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  stablePkgs = import inputs.nixpkgs-stable {
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (config.nixpkgs) config overlays;
  };
  sharedModules = [
    (lib.custom.relativeToRoot "modules/home")
    inputs.sops-nix.homeManagerModules.sops
    {
      # Home Manager shares the canonical sops-nix key via group access.
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
    }
  ];
in
{
  home-manager = {
    backupFileExtension = "backup";

    # Using the system configuration's `pkgs` argument in home-manager
    useGlobalPkgs = true;

    # Installation of user packages through the {option} `users.users.<name>.packages` option
    # useUserPackages = true;

    # Verbose output on activation
    verbose = true;

    # Extra modules added to all users
    sharedModules = [
      {
        # Let home-manager install and manage itself
        programs.home-manager.enable = true;
      }
    ]
    ++ sharedModules;

    # Provide flake inputs to Home Manager modules.
    extraSpecialArgs = {
      inherit inputs stablePkgs;
    };
  };
}
