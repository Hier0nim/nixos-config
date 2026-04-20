{
  lib,
  pkgs,
  ...
}:
{
  services = {
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = "${lib.getExe pkgs.tuigreet} --time --remember --asterisks --cmd ${lib.getExe' pkgs.niri "niri-session"}";
    };

    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  programs.dconf.enable = true;
}
