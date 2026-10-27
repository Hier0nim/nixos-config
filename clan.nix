{
  meta = {
    name = "hieronim-fleet";
    domain = "clan.pieczarkowo.me";
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
