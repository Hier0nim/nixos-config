{ pkgs, ... }:
{
  home.packages = with pkgs; [
    celluloid
    loupe
    nautilus
    papers
  ];
}
