{
  networking = {
    firewall = {
      enable = true;
      # The ports below are needed by Spotify.
      allowedTCPPorts = [ 4381 ];
      allowedUDPPorts = [ 4381 ];
    };
  };
}
