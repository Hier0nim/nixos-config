{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./home-common.nix

    (lib.custom.relativeToRoot "modules/home/profiles/desktop.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/dev.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/gaming.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/remote-admin.nix")
    (lib.custom.relativeToRoot "modules/home/common/services/copyparty-drive.nix")
    inputs.nix-index-database.homeModules.default
  ];

  custom = {
    hostName = "zephyrus-g14";
    services = {
      copypartyDrive.enable = true;
      codingAgents.enable = true;
    };
  };

  programs.nix-index-database.comma.enable = true;

  home.packages = with pkgs; [
    teams-for-linux
    proton-pass
    remmina
    qbittorrent
    proton-vpn
    protonmail-desktop
    libreoffice-fresh
    jellyfin-desktop
    via
  ];
}
