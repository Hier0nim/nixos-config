{ inputs, ... }:
# Fetches the user's name from home/options.nix
# And then fetches the system's stateVersion from system/options.nix
# HM's stateVersion should be in sync with the system's stateVersion to avoid mismatches and conflicts.
let
  inherit (import ./options.nix) userName;
  inherit (import ../system/options.nix) stateVersion;
in
{
  imports = [
    ./hyprland
    ./cli
    ./apps
    ./git.nix
    ./nix-settings.nix
    ./services.nix
    ./tools.nix
    inputs.catppuccin.homeManagerModules.catppuccin
  ];

  # Info required by home-manager and some session variables.
  home = {
    username = "${userName}";
    homeDirectory = "/home/${userName}";
    stateVersion = "${stateVersion}";
    sessionVariables.EDITOR = "nvim";
  };

  news.display = "silent";
  programs.starship.catppuccin.enable = true;
  programs.bat.catppuccin.enable = true;
  programs.btop.catppuccin.enable = true;
  programs.yazi.catppuccin.enable = true;
  programs.zellij.catppuccin.enable = true;

  programs.home-manager.enable = true;
}
