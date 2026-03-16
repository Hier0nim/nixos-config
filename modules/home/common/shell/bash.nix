{ pkgs, ... }:
{
  programs.bash = {
    enable = true;
    package = pkgs.bashInteractive;
    enableCompletion = true;

    shellAliases = {
      c = "clear";
      la = "ls -la";
      ll = "ls -l";
      nv = "nvim";
    };
  };
}
