{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gcc
    gnumake
    jq
    nixd
    ripgrep
    wget
    devenv
    nodejs
  ];
}
