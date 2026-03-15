{ config, pkgs, ... }:
{
  programs.zellij = {
    enable = true;
  };

  xdg.configFile."zellij/config.kdl".text =
    builtins.replaceStrings [ "@PROJECTS_DIR@" ] [ "${config.home.homeDirectory}/Projects" ]
      (builtins.readFile ./config.kdl);

  xdg.configFile."zellij/plugins/zellij-sessionizer.wasm".source = pkgs.fetchurl {
    url = "https://github.com/laperlej/zellij-sessionizer/releases/download/v0.4.3/zellij-sessionizer.wasm";
    hash = "sha256-AGuWbuRX7Yi9tPdZTzDKULXh3XLUs4navuieCimUgzQ=";
  };
}
