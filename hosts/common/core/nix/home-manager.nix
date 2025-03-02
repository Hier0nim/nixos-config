{lib, ...}: let
  sharedModules = [
    (lib.custom.relativeToRoot "modules/home")
  ];
in {
  home-manager = {
    backupFileExtension = "backup";

    # Using the system configuration's `pkgs` argument in home-manager
    useGlobalPkgs = true;

    # Installation of user packages through the {option} `users.users.<name>.packages` option
    # useUserPackages = true;

    # Verbose output on activation
    verbose = true;

    # Extra modules added to all users
    sharedModules =
      [
        {
          # Let home-manager install and manage itself
          programs.home-manager.enable = true;
        }
      ]
      ++ sharedModules;
  };
}
