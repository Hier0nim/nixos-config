{ pkgs, ... }:
{
  systemd.user.services.rog-control-center = {
    Unit = {
      Description = "Start rog-control-center after waybar is initialized";
      After = [ "waybar.service" ];
      Wants = [ "waybar.service" ];
    };

    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
      ExecStart = "${pkgs.asusctl}/bin/rog-control-center";
      Type = "simple";
      Restart = "on-failure";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
