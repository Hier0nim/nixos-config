{ pkgs, ... }:
{
  hardware.xone.enable = true; # xbox controller

  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = false; # disabled: appears before niri in greeter (S-01)
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    gamescope = {
      enable = true;
      capSysNice = true;
    };

    gamemode.enable = true;

  };

  environment.systemPackages = with pkgs; [
    mangohud
  ];
}
