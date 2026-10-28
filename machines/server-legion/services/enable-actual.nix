_: {
  virtualisation = {
    docker.enable = true;
    oci-containers = {
      backend = "docker";
      containers.enable-actual = {
        autoStart = true;
        image = "2manyvcos/enable-actual:2.4.4-actual26.10.0@sha256:578f2ed9ccb6911241e43ae533880cc4506868114a85bf9f3169e08c1b8314b4";
        ports = [ "127.0.0.1:3002:3002" ];
        volumes = [ "/var/lib/homelab/enable-actual:/data" ];
        environment = {
          PORT = "3002";
          DATA_DIR = "/data";
          PUBLIC_URL = "https://actual-sync.pieczarkowo.me";
          ACTUAL_URL = "https://kasa.pieczarkowo.me";
        };
        extraOptions = [ "--user=0:0" ];
      };
    };
  };
}
