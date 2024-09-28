{ pkgs, ... }:
{
  home.packages = with pkgs; [
    neovim
    lazygit
    ripgrep
    fd
    cargo
    zig
    gcc
  ];
}
