_: {
  services.ttyd = {
    enable = true;
    interface = "127.0.0.1";
    port = 7681;
    writeable = true;
  };
}
