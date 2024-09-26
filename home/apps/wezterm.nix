{ pkgs, inputs, ... }:
{
  home.sessionVariables.TERMINAL = "wezterm";

  programs.wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
  };

  home.file = {
    ".config/wezterm" = {
      source = ../../dotfiles/wezterm;
    };
  };
}
