{
  config,
  pkgs,
  ...
}:

let
  isKDEInstalled = config.services.desktopManager.plasma6.enable;
in
{
  # ASUS G14 Patched Kernel based off of Arch Linux Kernel
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  services = {
    # supergfxd controls GPU switching
    supergfxd.enable = true;

    # ASUS specific software. This also installs asusctl.
    asusd = {
      enable = true;
      enableUserService = true;
    };

    # Dependency of asusd
    power-profiles-daemon.enable = true;
  };

  programs.rog-control-center = {
    enable = true;
    autoStart = true;
  };

  # Install plasmoid if KDE is also installed.
  environment.systemPackages =
    with pkgs;
    builtins.filter (pkg: pkg != null) ([
      (if isKDEInstalled then supergfxctl-plasmoid else null)
    ]);
}
