{
  self,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../modules/nixos/common.nix
    ../../users/hieronim
    ./hardware.nix
    ./storage.nix
    ./services
  ];

  nix.settings.trusted-users = lib.mkOverride 40 [
    "root"
    "hieronim"
  ];

  nixpkgs.config.allowUnfree = true;
  nix.registry.nixpkgs.flake = self.inputs.nixpkgs;

  networking = {
    hostName = "server-legion";
    networkmanager.enable = true;
    networkmanager.wifi.powersave = false;
  };

  virtualisation.docker.package = pkgs.docker_29;

  users = {
    mutableUsers = false;
    users.hieronim = {
      isNormalUser = true;
      uid = 1000;
      home = "/home/hieronim";
      shell = pkgs.zsh;
      extraGroups = [ "wheel" ];
    };
    users.root.shell = pkgs.zsh;
  };

  programs = {
    zsh.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    cifs-utils
    hdparm
    lm_sensors
    smartmontools
    nvme-cli
    usbutils
    pciutils
    ghostty.terminfo
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  system.stateVersion = "25.05";
}
