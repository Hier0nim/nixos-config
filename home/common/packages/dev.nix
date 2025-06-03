{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gcc
    gnumake
    jq
    ripgrep
    wget
    devenv
  ];
}
