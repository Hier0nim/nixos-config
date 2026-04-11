{ config, lib, ... }:
{
  home.activation.ensureSshDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p -m 700 "${config.home.homeDirectory}/.ssh"
  '';

  sops.secrets = {
    ssh_github_personal = {
      sopsFile = config.custom.repoPath + "/secrets/common/ssh/github-personal.yaml";
      key = "key";
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_github_personal";
      mode = "0600";
    };
    ssh_hetzner_pieczarkownia = {
      sopsFile = config.custom.repoPath + "/secrets/common/ssh/hetzner-pieczarkownia.yaml";
      key = "key";
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_hetzner_pieczarkownia";
      mode = "0600";
    };
    ssh_server_legion = {
      sopsFile = config.custom.repoPath + "/secrets/common/ssh/server-legion.yaml";
      key = "key";
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_server_legion";
      mode = "0600";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    includes = [
      "~/.ssh/config.d/*.conf"
    ];

    matchBlocks."*" = {
      addKeysToAgent = "yes";
      serverAliveInterval = 3600;
      controlMaster = "auto";
      controlPath = "~/.ssh/ctrl-%r@%h:%p";
      controlPersist = "15m";
    };

    extraConfig =
      # sshconfig
      ''
        Host github.com github-personal
          HostName github.com
          User git
          IdentityFile ~/.ssh/id_ed25519_github_personal
          IdentitiesOnly yes

        Host pieczarkownia
          HostName <your-server-ip>
          User root
          IdentityFile ~/.ssh/id_ed25519_hetzner_pieczarkownia

        Host homelab
          HostName 192.168.8.2
          User hieronim
          IdentityFile ~/.ssh/id_ed25519_server_legion

        Host router
          HostName 192.168.8.1
          User root
          IdentityFile none
          PreferredAuthentications password
      '';
  };

  services.ssh-agent = {
    enable = true;
  };
}
