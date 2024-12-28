{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # Augment the existing programs.wezterm
  config = {
    # Wrap or modify the existing programs.wezterm.package
    programs.wezterm.package = lib.mkBefore inputs.wezterm.packages.${pkgs.system}.default;

    # Add extra configuration or logic
    programs.wezterm.extraConfig = lib.mkBefore (builtins.readFile ./wezterm.lua);
  };
}
