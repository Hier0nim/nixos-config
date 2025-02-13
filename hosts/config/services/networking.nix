{
  networking = {
    networkmanager = {
      enable = true;
      wifi = {
        backend = "iwd";
        powersave = true;
      };
    };

    firewall = {
      enable = true;
      checkReversePath = "loose";
    };
  };
}
