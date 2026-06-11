{ lib, pkgs, ... }:
{
  services.open-design.enable = lib.mkForce false;

  imports = [
    ./home-common.nix
    (lib.custom.relativeToRoot "modules/home/common/programs/nvim.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/dev.nix")
    (lib.custom.relativeToRoot "modules/home/common/programs/git.nix")
    (lib.custom.relativeToRoot "modules/home/common/shell/zellij")
    (lib.custom.relativeToRoot "modules/home/common/shell/default.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/remote-admin.nix")
  ];

  custom.hostName = "server-legion";
  custom.services.codingAgents.enable = true;

  home.packages = with pkgs; [
    comma
  ];
}
