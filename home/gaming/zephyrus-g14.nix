{
  inputs,
  ...
}:
{
  imports = [
    inputs.catppuccin.homeManagerModules.catppuccin
  ];

  home = {
    username = "gaming";
    homeDirectory = "/home/gaming";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "wezterm";
      BROWSER = "firefox";
      SHELL = "nu";
      FLAKE = "$HOME/nixos-config";
    };

    preferXdgDirectories = true; # whether to make programs use XDG directories whenever supported
  };
}
