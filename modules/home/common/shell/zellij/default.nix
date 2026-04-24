{
  config,
  lib,
  pkgs,
  ...
}:
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

  systemd.user.services.zellij-cleanup = {
    Unit = {
      Description = "Stop Zellij sessions when the graphical session ends";
      PartOf = [ "graphical-session.target" ];
      Before = [ "exit.target" ];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "-${lib.getExe pkgs.zellij} kill-all-sessions -y";
      TimeoutStopSec = 10;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
