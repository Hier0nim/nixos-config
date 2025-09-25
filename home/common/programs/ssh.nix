{
  programs.ssh.matchBlocks."*" = {
    enable = true;
    includes = [
      "~/.ssh/config.d/*.config"
    ];
    addKeysToAgent = "yes";
    serverAliveInterval = 3600;
    controlMaster = "auto";
    controlPath = "~/.ssh/ctrl-%r@%h:%p";
    controlPersist = "15m";
  };
}
