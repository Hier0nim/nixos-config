# NixOS module: SSH credentials and the Home Manager client that uses them.
{ config, ... }:
let
  vars = config.clan.core.vars.generators;
  homeDirectory = config.users.users.hieronim.home;
in
{
  # Persist existing private keys; do not generate replacement identities.
  clan.core.vars.generators = {
    hieronim-ssh-github-personal = {
      prompts.key = {
        description = "Existing private key for github-personal";
        type = "multiline-hidden";
        persist = true;
      };
      files.key.owner = "hieronim";
    };

    hieronim-ssh-forgejo = {
      prompts.key = {
        description = "Existing private key for forgejo";
        type = "multiline-hidden";
        persist = true;
      };
      files.key.owner = "hieronim";
    };

    hieronim-ssh-hetzner-pieczarkownia = {
      prompts.key = {
        description = "Existing private key for hetzner-pieczarkownia";
        type = "multiline-hidden";
        persist = true;
      };
      files.key.owner = "hieronim";
    };

    hieronim-ssh-server-legion = {
      prompts.key = {
        description = "Existing private key for server-legion";
        type = "multiline-hidden";
        persist = true;
      };
      files.key.owner = "hieronim";
    };

    # Hostnames stay secret, so render this fragment outside the Nix store.
    hieronim-ssh-hosts = {
      prompts = {
        server-legion = {
          description = "Existing private hostname/address for homelab";
          type = "hidden";
        };
      };
      files.config.owner = "hieronim";
      script = ''
        printf '%s\n' \
          'Host homelab' \
          "  HostName $(cat "$prompts/server-legion")" \
          > "$out/config"
      '';
    };
  };

  home-manager.users.hieronim =
    { lib, ... }:
    {
      home.activation.ensureSshDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p -m 700 "${homeDirectory}/.ssh"
      '';

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        includes = [
          vars.hieronim-ssh-hosts.files.config.path
          "~/.ssh/config.d/*.conf"
        ];
        settings = {
          "*" = {
            AddKeysToAgent = "yes";
            ServerAliveInterval = 3600;
            ControlMaster = "auto";
            ControlPath = "~/.ssh/ctrl-%r@%h:%p";
            ControlPersist = "15m";
          };
          "github.com github-personal" = {
            HostName = "github.com";
            User = "git";
            IdentityFile = vars.hieronim-ssh-github-personal.files.key.path;
            IdentitiesOnly = true;
          };
          "git.pieczarkowo.me" = {
            User = "forgejo";
            IdentityFile = vars.hieronim-ssh-forgejo.files.key.path;
            IdentitiesOnly = true;
          };
          homelab = {
            User = "hieronim";
            IdentityFile = vars.hieronim-ssh-server-legion.files.key.path;
            IdentitiesOnly = true;
          };
          "legion-workstation workstation-dev" = {
            HostName = "10.233.10.2";
            Port = 22;
            User = "hieronim";
            IdentityFile = vars.hieronim-ssh-server-legion.files.key.path;
            IdentitiesOnly = true;
            ProxyJump = "homelab";
            HostKeyAlias = "server-legion-workstation";
            ForwardAgent = true;
          };
          router = {
            HostName = "192.168.8.1";
            User = "root";
            IdentityFile = "none";
            PreferredAuthentications = "password";
          };
        };
      };
      services.ssh-agent.enable = true;
    };
}
