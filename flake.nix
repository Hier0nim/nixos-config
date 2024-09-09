{
  description = "Hier0nim's nixos config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    
    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Hyprland
    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      submodules = true;
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    # Blocklist-hosts
    blocklist-hosts = {
      url = "github:StevenBlack/hosts";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }: let
    inherit (self) outputs;

    # ---- SYSTEM SETTINGS ---- #
    systemSettings = {
      system = "x86_64-linux";
      hostname = "elitebook830";  # This can be dynamically changed based on the system
      timezone = "Europe/Warsaw";
      locale = "en_US.UTF-8";
    };

    # ----- USER SETTINGS ----- #
    userSettings = rec {
      username = "hieronim";
      gitUsername = "Hier0nim";
      gitEmail = "hieronimdaniel@gmail.com";
      theme = "io";
      browser = "librewolf";
      term = "wezterm";
      font = "JetBrains Mono";
      fontPkg = pkgs.jetbrains-mono;
      editor = "nvim";
      spawnEditor = if (editor == "vim" || editor == "nvim" || editor == "nano")
                    then "exec " + term + " -e " + editor
                    else editor;
    };

    # Importing packages with nixpkgs
    pkgs = import inputs.nixpkgs {
      system = systemSettings.system;
      config = {
        allowUnfree = true;
        allowUnfreePredicate = (_: true);
      };
    };

    supportedSystems = [ "x86_64-linux" ];

    # Generates attributes for supported systems
    forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;

  in {
    # NixOS configurations for rebuilding the system
    nixosConfigurations = {
      elitebook830 = nixpkgs.lib.nixosSystem {
        system = systemSettings.system;
        modules = [
            (./. + "/hosts" + ("/" + systemSettings.hostname) + "/configuration.nix")
        ];
        specialArgs = {
          inherit inputs;
          inherit outputs;
          inherit userSettings;
          inherit systemSettings;
        };
      };
    };

    # Home Manager configurations
    homeConfigurations = {
      user = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./hosts/elitebook830/home.nix
        ];
        extraSpecialArgs = {
          inherit inputs;
          inherit outputs;
          inherit userSettings;
          inherit systemSettings;
        };
      };
    };

    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;
  };
}
