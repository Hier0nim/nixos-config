{ pkgs, ... }:
{
  home.packages = with pkgs; [
    celluloid
    gpu-screen-recorder
    loupe
    nautilus
    papers
  ];
}
