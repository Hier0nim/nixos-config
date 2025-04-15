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
        package = lib.mkBefore pkgs.wezterm;
        # package = lib.mkBefore inputs.wezterm.packages.${pkgs.system}.default;

        # Add extra configuration or logic
        extraConfig = lib.mkBefore (builtins.readFile ./wezterm.lua);
      };
    };
  };
}
