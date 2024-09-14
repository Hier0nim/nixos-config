# Fetch the fontName variable from system/options.nix to determine which font to use.
let
  inherit (import ../system/options.nix) fontName;
in {
  home.sessionVariables.TERMINAL = "wezterm";

  programs.wezterm = {
    enable = true;
  };

  home.file = {
    ".config/wezterm" = {
      source = "./../dotfiles/wezterm/";
      target = "copy";
    };
  };
}
