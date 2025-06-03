{ pkgs, ... }:
{
  home.packages = with pkgs; [
    spotify
    papers
    loupe
  ];
}
