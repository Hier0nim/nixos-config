{inputs, ...}:

{
  home.sessionVariables.BROWSER = "librewolf";

  programs.librewolf = {
    enable = true;
  };
}
