{
  # Required by system/networking.nix
  hostName = "NixOS";

  # Required by system/locale.nix
  theLocale = "en_US.UTF-8";

  # Required by system/locale.nix
  theTimezone = "Europe/Warsaw";

  # Required by flake.nix
  system = "x86_64-linux";

  # Required by system/fonts.nix
  fontName = "Iosevka Nerd Font";

  # Do not modify the variable below.
  # We're using it to make sure that home-manager's stateVersion is in sync with the system's stateVersion.
  stateVersion = "24.05";
}
