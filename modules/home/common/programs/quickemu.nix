{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    quickemu = {
      enable = lib.mkEnableOption {
        description = "Enable Quickemu";
        default = false;
      };
    };
  };

  config = lib.mkIf config.quickemu.enable {
    home.packages = with pkgs; [
      quickemu
      # quickgui
    ];
  };
}
