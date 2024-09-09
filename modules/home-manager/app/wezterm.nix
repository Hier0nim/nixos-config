{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    wezterm
  ];
}
