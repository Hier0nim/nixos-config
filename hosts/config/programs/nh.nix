{
  programs.nh = {
    enable = true;
    flake = "/home/hieronim/nixos-config";
    clean = {
      enable = true;
      extraArgs = "--keep-since 1w";
    };
  };
}
