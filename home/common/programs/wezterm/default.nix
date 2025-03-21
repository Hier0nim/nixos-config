{
  lib,
  pkgs,
  ...
}:
{
  # Augment the existing programs.wezterm
  config = {
    programs = {
      wezterm = {
        enable = lib.mkBefore true;

        # Wrap or modify the existing programs.wezterm.package
        # programs.wezterm.package = lib.mkBefore inputs.wezterm.packages.${pkgs.system}.default;
        package = lib.mkBefore pkgs.wezterm;

        # Add extra configuration or logic
        extraConfig = lib.mkBefore (builtins.readFile ./wezterm.lua);
      };
    };
  };
}
