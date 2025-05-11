{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (import ../scripts.nix { inherit pkgs; }) suspendScript;
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pgrep hyprlock || ${lib.getExe config.programs.hyprlock.package}";
        before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 60;
          # save the current brightness and dim the screen
          on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s s 10%";

          # restore the previous brighness
          on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
        }
        {
          timeout = 300;
          on-timeout = "${pkgs.systemd}/bin/loginctl lock-session";
        }
        {
          timeout = 330;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 600;
          on-timeout = suspendScript.outPath;
        }
      ];
    };
  };
}
