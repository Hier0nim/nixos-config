{
  customLib,
  lib,
  pkgs,
  ...
}:
{
  services.open-design.enable = lib.mkForce false;

  imports = [
    ./home-common.nix
    (customLib.relativeToRoot "modules/home/common/programs/nvim.nix")
    (customLib.relativeToRoot "modules/home/profiles/dev.nix")
    (customLib.relativeToRoot "modules/home/common/programs/git.nix")
    (customLib.relativeToRoot "modules/home/common/shell/zellij")
    (customLib.relativeToRoot "modules/home/common/shell/default.nix")
    (customLib.relativeToRoot "modules/home/profiles/remote-admin.nix")
  ];

  custom.hostName = "server-legion";
  custom.services.codingAgents.enable = true;

  home.packages = with pkgs; [
    comma
  ];
}
