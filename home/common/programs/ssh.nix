{
  programs.ssh = {
    enable = true;

    includes = [
      "~/.ssh/config.d/*.conf"
    ];

    enableDefaultConfig = false;

    matchBlocks."*" = {
      addKeysToAgent = "yes";
      serverAliveInterval = 3600;
      controlMaster = "auto";
      controlPath = "~/.ssh/ctrl-%r@%h:%p";
      controlPersist = "15m";
    };
  };

  services.ssh-agent.enable = true;
}
