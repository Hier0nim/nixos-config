{ pkgs, ... }:
{
  environment.shells = [ pkgs.zsh ];
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
}
