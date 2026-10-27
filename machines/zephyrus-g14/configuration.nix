{
  self,
  config,
  pkgs,
  ...
}:
{
  imports = [
    self.inputs.determinate.nixosModules.default
    ../../modules/nixos/common.nix
    ./hardware.nix
    ./desktop.nix
    ../../users/hieronim
    ../../users/hieronim/workstation.nix
    ../../users/hieronim/ssh.nix
    ../../users/hieronim/copyparty.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.registry.nixpkgs.flake = self.inputs.nixpkgs;

  networking = {
    hostName = "zephyrus-g14";
    networkmanager.enable = true;
  };

  nix = {
    settings = {
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://devenv.cachix.org"
        "https://noctalia.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  programs = {
    zsh.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    nix-ld = {
      enable = true;
      libraries = [ pkgs.stdenv.cc.cc ];
    };
  };

  users = {
    mutableUsers = false;
    users.hieronim = {
      uid = 1000;
      home = "/home/hieronim";
      shell = pkgs.zsh;
      extraGroups = builtins.filter (group: builtins.hasAttr group config.users.groups) [
        "networkmanager"
        "audio"
        "video"
        "input"
        "dialout"
        "gamemode"
        "i2c"
      ];
    };
    users.root.shell = pkgs.zsh;
  };

  # SSH is used only for local Clan updates.
  services.openssh = {
    openFirewall = false;
    listenAddresses = [
      { addr = "127.0.0.1"; }
      { addr = "::1"; }
    ];
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  environment = {
    localBinInPath = true;
    systemPackages = [ pkgs.git ];
  };

  # Keep the version used for the original installation.
  system.stateVersion = "25.05";
}
