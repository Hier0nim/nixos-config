{ lib, pkgs, ... }:
{
  imports = [
    ./home-common.nix
    (lib.custom.relativeToRoot "modules/home/common/programs/nvim.nix")
    (lib.custom.relativeToRoot "modules/home/common/programs/git.nix")
    (lib.custom.relativeToRoot "modules/home/common/shell/zellij")
    (lib.custom.relativeToRoot "modules/home/common/shell/default.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/remote-admin.nix")
  ];

  home.packages = with pkgs; [
    comma
  ];
}
