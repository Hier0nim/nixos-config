{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.catppuccin.homeModules.catppuccin

    ../common/programs/git.nix
    ../common/programs/lazygit.nix
    ../common/programs/fastfetch.nix
    ../common/programs/ssh.nix
    ../common/shell
  ];
  home.packages = with pkgs; [
    inputs.nixvim.packages.x86_64-linux.default

    gcc
    gnumake
    jq
    p7zip
    ripgrep
    unrar
    unzip
    zip
    wget
    wl-clipboard
  ];

  home = {
    username = "hieronim";
    homeDirectory = "/home/hieronim";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "wezterm";
      BROWSER = "firefox";
      SHELL = "nu";
      FLAKE = "$HOME/nixos-config";
      USERNAME = "hieronim";
    };
  };
}
