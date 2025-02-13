{ pkgs, ... }:
{
  users.users.hieronim = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "wheel"
      "audio"
      "video"
      "input"
      "network"
      "networkmanager"
      "plugdev"
      "libvirtd"
      "mysql"
      "docker"
      "podman"
      "git"
    ];
    hashedPassword = "$y$j9T$A393jWCF3yvUwEwDdalP9/$9JAJVGgOujBcX/SMg8zRuuagNfWH9y6aochFeAsEOC1";
    shell = pkgs.nushell;
  };
}
