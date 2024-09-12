{inputs, ...}:
# Fetches the user's name from home/options.nix
# And then fetches the system's stateVersion from system/options.nix
# HM's stateVersion should be in sync with the system's stateVersion to avoid mismatches and conflicts.
let
  inherit (import ./options.nix) userName;
  inherit (import ../system/options.nix) stateVersion;
in {
  imports = [
    ./cli.nix
    ./files.nix
    ./librewolf.nix
    ./git.nix
    ./gtk.nix
    ./hyprland.nix
    ./hyprlock.nix
    ./izrss.nix
    ./wezterm.nix
    ./mako.nix
    ./nushell.nix
    ./nix-settings.nix
    ./rofi.nix
    ./services.nix
    ./starship.nix
    ./tools.nix
    ./waybar.nix
    ./xdg.nix
    ./yazi.nix
    ./neovim.nix
    inputs.catppuccin.homeManagerModules.catppuccin
    inputs.hyprland.homeManagerModules.default
    inputs.hypridle.homeManagerModules.hypridle
    inputs.hyprlock.homeManagerModules.hyprlock
    inputs.izrss.homeManagerModules.default
  ];

  # Info required by home-manager and some session variables.
  home = {
    username = "${userName}";
    homeDirectory = "/home/${userName}";
    stateVersion = "${stateVersion}";
    sessionVariables.EDITOR = "nvim";
  };

  news.display = "silent";
  catppuccin.flavour = "macchiato";
  programs.home-manager.enable = true;
}
