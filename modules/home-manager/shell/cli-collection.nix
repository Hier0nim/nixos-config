{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Command Line
    killall
    brightnessctl
    unzip
    pandoc
    hwinfo
    pciutils
    gnumake
    unzip
    zig
    gcc
    cargo
    ripgrep
    fd
    neovim
  ];
}
