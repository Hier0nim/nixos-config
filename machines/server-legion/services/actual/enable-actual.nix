_: {
  virtualisation = {
    docker.enable = true;
    oci-containers = {
      backend = "docker";
      containers.enable-actual = {
        autoStart = true;
        image = "2manyvcos/enable-actual:2.4.4-actual26.10.0@sha256:578f2ed9ccb6911241e43ae533880cc4506868114a85bf9f3169e08c1b8314b4";
        volumes = [ "/var/lib/homelab/enable-actual:/data" ];
        environment = {
          PORT = "3002";
          LISTEN_ADDRESS = "127.0.0.1";
          DATA_DIR = "/data";
          PUBLIC_URL = "https://actual-sync.pieczarkowo.me";
        };
        # Reach Actual's loopback listener without exposing this UI on the LAN.
        extraOptions = [
          "--network=host"
          "--user=0:0"
        ];
      };
    };
  };

  systemd.services.docker-enable-actual = {
    after = [ "actual.service" ];
    wants = [ "actual.service" ];
  };
}
