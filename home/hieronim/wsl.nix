{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ../common/programs/git.nix
    ../common/programs/lazygit.nix
    ../common/programs/ssh.nix
    ../common/shell
  ];

  home.packages = with pkgs; [
    inputs.nixCats.packages.x86_64-linux.default

    gcc
    gnumake
    jq
    p7zip
    ripgrep
    unrar
    unzip
    zip
    wget
    xclip
    dos2unix
    devenv

    # webkit debugging
    epiphany
  ];

  programs.nushell.environmentVariables.ZELLIJ_AUTO_START = true;

  home = {
    username = "hieronim";
    homeDirectory = "/home/hieronim";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "nvim";
      TERM = "ghostty";
      BROWSER = "firefox";
      SHELL = "nu";
      FLAKE = "$HOME/nixos-config";
      USERNAME = "hieronim";
    };
  };
}
