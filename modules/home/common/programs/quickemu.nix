{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    custom.programs.quickemu = {
      enable = lib.mkEnableOption {
        description = "Enable Quickemu";
        default = false;
      };
    };
  };

  config = lib.mkIf config.custom.programs.quickemu.enable {
    home.packages = with pkgs; [
      quickemu
      # quickgui
    ];
  };
}
