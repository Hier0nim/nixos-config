{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (import ./scripts.nix { inherit pkgs; }) suspendScript;
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = lib.getExe config.programs.hyprlock.package;
        before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
      };

      listener = [
        {
          timeout = 60;
          # save the current brightness and dim the screen
          on-timeout = "brightnessctl -s s 10%";

          # restore the previous brighness
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 120;
          on-timeout = "hyprlock";
        }
        {
          timeout = 180;
          on-timeout = suspendScript.outPath;
        }
      ];
    };
  };
}
