{ ... }:
{
  imports = [
    ./options
  ];

  # Automatic home-manager profile garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
