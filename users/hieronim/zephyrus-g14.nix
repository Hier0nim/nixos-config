{ lib, pkgs, ... }:
{
  imports = [
    ./home-common.nix

    (lib.custom.relativeToRoot "modules/home/profiles/desktop.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/dev.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/gaming.nix")
    (lib.custom.relativeToRoot "modules/home/profiles/remote-admin.nix")
    (lib.custom.relativeToRoot "modules/home/common/services/copyparty-drive.nix")
  ];

  home.packages = with pkgs; [
    teams-for-linux
    proton-pass
    remmina
    qbittorrent
    proton-vpn
    protonmail-desktop
    comma
    libreoffice-fresh
    jellyfin-desktop
    via
  ];
}
