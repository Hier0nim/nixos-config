{ self, ... }:
let
  inherit (self) inputs;
in
{
  meta = {
    name = "hieronim-fleet";
    domain = "clan.pieczarkowo.me";
  };

  # Machine composition; host-specific settings live in machines/.
  machines.zephyrus-g14 = {
    imports = [
      inputs.determinate.nixosModules.default
      inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402x-nvidia
      inputs.asus-px-keyboard-tool.nixosModules.default
      inputs.umbriel.nixosModules.default
      inputs.noctalia.nixosModules.default
      inputs.noctalia-greeter.nixosModules.default
      ./users/hieronim
    ];

    nix.registry.nixpkgs.flake = inputs.nixpkgs;
  };

  inventory.machines.zephyrus-g14 = {
    tags = [
      "personal"
      "laptop"
    ];
    # Self-management only: run updates from zephyrus-g14, not another host.
    deploy.targetHost = "root@127.0.0.1";
  };

  inventory.instances = {
    sshd = {
      module.name = "sshd";
      roles.server = {
        machines.zephyrus-g14 = { };
        settings.authorizedKeys.hieronim-zephyrus-g14 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJGzC873PNMwJiXAG8Gl9EdK6GmuQW6QZL8fb7/yGX4B hieronim@zephyrus-g14";
      };
    };

    user-root = {
      module.name = "users";
      roles.default = {
        machines.zephyrus-g14 = { };
        settings.user = "root";
      };
    };

    user-hieronim = {
      module.name = "users";
      roles.default = {
        machines.zephyrus-g14 = { };
        settings = {
          user = "hieronim";
          groups = [ "wheel" ];
        };
      };
    };

    wifi = {
      module.name = "wifi";
      roles.default = {
        machines.zephyrus-g14 = { };
        settings.networks.pieczarkowo = { };
      };
    };
  };
}
