{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    lazygit
    ripgrep
    fd
    cargo
    zig
    neovim
    gcc
  ];
}
