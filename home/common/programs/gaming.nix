{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (heroic.override {
      extraPkgs = pkgs: [
        pkgs.gamescope
      ];
    })
    prismlauncher
    mangohud
  ];
}
