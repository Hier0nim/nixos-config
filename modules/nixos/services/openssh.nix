{ config, lib, ... }:
let
  cfg = config.custom.services.openssh;
in
{
  options.custom.services.openssh.enable = lib.mkEnableOption "OpenSSH server with fail2ban";

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
      };
      startWhenNeeded = false;
      openFirewall = true;
    };

    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
    };
  };
}
