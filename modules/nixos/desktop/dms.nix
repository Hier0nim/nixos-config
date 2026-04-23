{
  pkgs,
  config,
  inputs,
  ...
}:
{
  programs.niri.enable = true;

  services = {
    accounts-daemon.enable = true;

    displayManager.dms-greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = config.users.users.hieronim.home;
      package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };

    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  programs.dconf.enable = true;
}
