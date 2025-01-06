{ pkgs, ... }:
rec {
  system = "x86_64-linux";
  hostname = "NixOS";
  username = "hieronim";
  profile = "laptop";
  timezone = "Europe/Warsaw";
  locale = "en_US.UTF-8";
  layout = "pl";
  gitname = "Hier0nim";
  gitmail = "hieronimdaniel@gmail.com";
  dotfilesDir = "/home/${username}/nixos-config";
  wm = "hyprland";

  font = "Iosevka Nerd Font";
  fontPkg = [
    pkgs.nerd-fonts.iosevka
    pkgs.nerd-fonts.jetbrains-mono
  ];
  fontSize = 12;

  # Session variables.
  editor = "nvim";
  browser = "firefox";
  term = "wezterm";

  # Do not modify the variable below.
  # We're using it to make sure that home-manager's stateVersion is in sync with the system's stateVersion.
  stateVersion = "24.05";
}
