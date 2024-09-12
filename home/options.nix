rec {
  # Required by home/firefox.nix (for setting up user profile) and system/users.nix (to add the user to the system)
  userName = "hieronim";

  # Required by home/firefox.nix (for setting up user profile)
  userFullName = "hieronim";

  # Required by home/git.nix
  gitUserName = "Hier0nim";

  # Required by home/git.nix
  gitEmail = "hieronimdaniel@gmail.com";

  # Required by home/nushell.nix
  dotfilesDir = "/home/${userName}/nixos-config";
}
