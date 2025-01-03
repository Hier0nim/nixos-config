{ pkgs, settings, ... }:
{
  imports = [
    ../../system/security
    ../../system/hardware
    ../../system/network
    ../../system/kanata
    ./hardware-configuration.nix
    (./. + "../../../system/wm" + ("/" + "${settings.wm}") + ".nix")
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = true;
    };

    hostName = "${settings.hostname}";
  };

  # Timezone
  time = {
    timeZone = "${settings.timezone}";
    hardwareClockInLocalTime = true;
  };

  # Locale.
  i18n.defaultLocale = settings.locale;
  i18n.extraLocaleSettings = {
    LC_ALL = settings.locale;
  };

  # Users.
  users.users.${settings.username} = {
    isNormalUser = true;
    description = settings.username;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    hashedPassword = "$y$j9T$A393jWCF3yvUwEwDdalP9/$9JAJVGgOujBcX/SMg8zRuuagNfWH9y6aochFeAsEOC1";
    shell = pkgs.nushell;
  };

  # See https://nix.dev/permalink/stub-ld.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
  ];

  # List of globally installed packages.
  environment.systemPackages = with pkgs; [
    nixfmt-rfc-style
    home-manager
    nix-index
    pciutils
    go-mtpfs
    lsof
    wget
    git
    vim
    unzip
  ];

  # A lot of mpris packages require it.
  services.gvfs.enable = true;
  services.upower.enable = true;

  nix = {
    # Keep build-time dependencies around to be able to rebuild while being offline.
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';

    settings = {
      auto-optimise-store = true;
      trusted-users = [ "${settings.username}" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Enable auto cleanup.
    gc = {
      automatic = true;
      persistent = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "${settings.stateVersion}";
}
