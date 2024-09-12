{inputs, pkgs, ...}:

{
  programs.neovim = {
    enable = true;
  };

  home.packages = with pkgs; [
    lazygit
    ripgrep
    fd
    cargo
    zig
  ];
}
