{inputs, ...}:
# Fetches the user's name from home/options.nix
# And then fetches the system's stateVersion from system/options.nix
# HM's stateVersion should be in sync with the system's stateVersion to avoid mismatches and conflicts.
let
  inherit (import ./options.nix) userName;
  inherit (import ../system/options.nix) stateVersion;
in {
  imports = [
    ./hyprland.nix
    ./hyprlock.nix
    ./cli.nix
    ./files.nix
    ./git.nix
    ./gtk.nix
    ./mako.nix
    ./wezterm.nix
    ./librewolf.nix
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
  ];

  # Info required by home-manager and some session variables.
  home = {
    username = "${userName}";
    homeDirectory = "/home/${userName}";
    stateVersion = "${stateVersion}";
    sessionVariables.EDITOR = "nvim";
  };

  news.display = "silent";
  # catppuccin.flavour = "mocha";
  programs.starship.catppuccin.enable = true;
  programs.bat.catppuccin.enable = true;
  programs.btop.catppuccin.enable = true;
  programs.yazi.catppuccin.enable = true;

  programs.home-manager.enable = true;
}
