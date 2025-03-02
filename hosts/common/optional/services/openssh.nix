{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
    startWhenNeeded = true;
    openFirewall = true;
  };

  services.fail2ban.enable = true;
}
