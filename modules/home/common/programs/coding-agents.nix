{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    claude-code
    codex
    inputs.serena.packages.${pkgs.stdenv.hostPlatform.system}.serena
    pi-coding-agent
  ];
}
