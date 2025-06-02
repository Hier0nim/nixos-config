{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;
    settings = {
      font-family = "JetBrainsMono Nerd Font Mono";
      font-size = 12;
      theme = "catppuccin-mocha";
      resize-overlay = "never";
      window-decoration = "none";
    };
  };
}
