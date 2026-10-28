{ self, pkgs, ... }:
{
  imports = [ self.inputs.nixos-hardware.nixosModules.lenovo-legion-y530-15ich ];

  boot = {
    initrd.systemd.enable = true;
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 5;
      };
      timeout = 3;
    };
    tmp.cleanOnBoot = true;
    kernelPackages = pkgs.linuxPackages;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = false;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

}
