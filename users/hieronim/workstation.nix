{
  inputs,
  lib,
  ...
}:
{
  services.open-design.enable = lib.mkForce false;

  imports = [
    ./home-common.nix
    ../../modules/home/common/programs/nvim.nix
    ../../modules/home/common/programs/lazygit.nix
    ../../modules/home/common/packages/dev.nix
    ../../modules/home/common/programs/git.nix
    ../../modules/home/common/shell/zellij
    ../../modules/home/common/shell/default.nix
    ../../modules/home/ssh/ssh.nix
    inputs.pi-config.homeManagerModules.default
    inputs.nix-index-database.homeModules.default
  ];

  custom.hostName = "workstation";

  programs.nix-index-database.comma.enable = true;
}
