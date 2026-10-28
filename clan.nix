{
  meta = {
    name = "hieronim-fleet";
    domain = "clan.pieczarkowo.me";
  };

  inventory.machines = {
    zephyrus-g14 = {
      tags = [
        "personal"
        "laptop"
      ];
      # Self-management only: run updates from zephyrus-g14, not another host.
      deploy.targetHost = "root@127.0.0.1";
    };

    server-legion.tags = [
      "server"
      "homelab"
    ];
  };

  inventory.instances = {
    sshd = {
      module.name = "sshd";
      roles.server = {
        machines = {
          zephyrus-g14 = { };
          server-legion = { };
        };
        settings.authorizedKeys = {
          hieronim-zephyrus-g14 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJGzC873PNMwJiXAG8Gl9EdK6GmuQW6QZL8fb7/yGX4B hieronim@zephyrus-g14";
          hieronim-server-legion = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpMtn/1wYa2EhgfnGjU0ZHk4mBKz1Mr0SjioMu2h4Ya server-legion";
        };
      };
    };

    user-root = {
      module.name = "users";
      roles.default = {
        machines = {
          zephyrus-g14 = { };
          server-legion = { };
        };
        settings.user = "root";
      };
    };

    user-hieronim = {
      module.name = "users";
      roles.default = {
        machines = {
          zephyrus-g14 = { };
          server-legion = { };
        };
        settings = {
          user = "hieronim";
          groups = [ "wheel" ];
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpMtn/1wYa2EhgfnGjU0ZHk4mBKz1Mr0SjioMu2h4Ya server-legion"
          ];
        };
      };
    };

    wifi = {
      module.name = "wifi";
      roles.default = {
        machines = {
          zephyrus-g14 = { };
          server-legion = { };
        };
        settings.networks.pieczarkowo = { };
      };
    };

    borgbackup = {
      module = {
        name = "borgbackup";
        input = "clan-core";
      };
      roles.client.machines.server-legion.settings = {
        startAt = "*-*-* 03:30:00";
        destinations.hetzner-storagebox = {
          repo = "u654384-sub2@u654384-sub2.your-storagebox.de:/./borgbackup";
          rsh = "ssh -p 23 -oStrictHostKeyChecking=accept-new -i /run/secrets/vars/per-machine/server-legion/borgbackup/borgbackup.ssh";
        };
      };
    };
  };
}
