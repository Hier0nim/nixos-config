_: {
  services.actual = {
    enable = true;
    openFirewall = false;
    settings = {
      hostname = "127.0.0.1";
      port = 3100;
      dataDir = "/var/lib/actual";
    };
  };
}
