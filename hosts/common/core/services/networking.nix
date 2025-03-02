{
  networking = {
    networkmanager = {
      enable = true;
      wifi = {
        backend = "iwd";
        powersave = true;
      };
    };
  };
}
