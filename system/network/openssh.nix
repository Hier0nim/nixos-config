{
  services.openssh = {
    enable = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
    };
    startWhenNeeded = true;
    openFirewall = true;
  };

  services.fail2ban.enable = true;
}
