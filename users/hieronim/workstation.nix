{ lib, pkgs, ... }:
{
  services.open-design.enable = lib.mkForce false;

  imports = [
    ./home-common.nix
    ../../modules/home/common/programs/nvim.nix
    ../../modules/home/common/packages/dev.nix
    ../../modules/home/common/programs/git.nix
    ../../modules/home/common/shell/zellij
    ../../modules/home/common/shell/default.nix
    ../../modules/home/ssh/ssh.nix
  ];

  custom.hostName = "workstation";

  home.packages = with pkgs; [
    comma
  ];
}
