{
  pkgs,
  self,
  ...
}:
let
  user = "hieronim";
  hostAddress = "10.233.10.1";
  containerAddress = "10.233.10.2";
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpMtn/1wYa2EhgfnGjU0ZHk4mBKz1Mr0SjioMu2h4Ya server-legion";
in
{
  containers.workstation = {
    autoStart = true;
    privateNetwork = true;
    inherit hostAddress;
    localAddress = containerAddress;
    forwardPorts = [
      {
        protocol = "tcp";
        hostPort = 2222;
        containerPort = 22;
      }
    ];
    config = {
      imports = [ self.inputs.home-manager.nixosModules.default ];

      networking = {
        hostName = "workstation";
        nameservers = [
          "1.1.1.1"
          "9.9.9.9"
        ];
        firewall = {
          enable = true;
          allowedTCPPorts = [ 22 ];
        };
      };

      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          X11Forwarding = false;
          AllowUsers = [ user ];
        };
      };

      programs.zsh.enable = true;
      users = {
        mutableUsers = false;
        defaultUserShell = pkgs.zsh;
        users.root.openssh.authorizedKeys.keys = [ sshKey ];
        users.${user} = {
          isNormalUser = true;
          uid = 1000;
          home = "/home/${user}";
          shell = pkgs.zsh;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ sshKey ];
        };
      };

      nixpkgs.config.allowUnfree = true;
      nix = {
        registry.nixpkgs.flake = self.inputs.nixpkgs;
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [ user ];
        };
      };

      environment.systemPackages = with pkgs; [
        curl
        git
        socat
        zsh
      ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${user} = import ../../../users/hieronim/home.nix;
      };

      system.stateVersion = "25.05";
    };
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-workstation" ];
    externalInterface = "wlp7s0";
  };

  systemd.services."container@workstation".serviceConfig = {
    MemoryMax = "8G";
    CPUQuota = "400%";
    TasksMax = 8192;
  };
}
