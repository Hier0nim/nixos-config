{ pkgs, inputs, ... }:
# Fetch the fontName variable from system/options.nix to determine which font to use.
let
  inherit (import ../system/options.nix) fontName;
in
{
  home.sessionVariables.TERMINAL = "wezterm";

  programs.wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
  };

  home.file = {
    ".config/wezterm" = {
      source = ../dotfiles/wezterm;
    };
  };
}
