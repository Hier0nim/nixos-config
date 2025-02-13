{
  programs.direnv = {
    enable = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  home.sessionVariables.DIRENV_LOG_FORMAT = "";
}
