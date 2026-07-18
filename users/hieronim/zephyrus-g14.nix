{
  customLib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./home-common.nix

    (customLib.relativeToRoot "modules/home/profiles/desktop.nix")
    (customLib.relativeToRoot "modules/home/profiles/dev.nix")
    (customLib.relativeToRoot "modules/home/profiles/gaming.nix")
    (customLib.relativeToRoot "modules/home/profiles/remote-admin.nix")
    (customLib.relativeToRoot "modules/home/common/services/copyparty-drive.nix")
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
