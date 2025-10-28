{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.custom.programs.winboat.enable = lib.mkEnableOption "";

  config = lib.mkIf config.custom.programs.winboat.enable {
    virtualisation.docker.enable = true;

    environment.systemPackages = [
      pkgs.winboat
    ];
  };
}
