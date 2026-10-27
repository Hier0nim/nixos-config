{
  self,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    self.inputs.umbriel.nixosModules.default
    self.inputs.noctalia.nixosModules.default
    self.inputs.noctalia-greeter.nixosModules.default
  ];

  security.rtkit.enable = true;

  programs = {
    umbriel.enable = true;
    noctalia = {
      enable = true;
      recommendedServices.enable = true;
      systemd = {
        enable = true;
        target = "umbriel-session.target";
      };
    };
    dconf.enable = true;
    seahorse.enable = true;
    rog-control-center.enable = true;
    steam = {
      enable = true;
      gamescopeSession.enable = false;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
    };
    gamescope = {
      enable = true;
      capSysNice = true;
    };
    gamemode.enable = true;
  };

  services = {
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
    printing.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;
    gnome = {
      gnome-keyring.enable = true;
      localsearch.enable = true;
      tinysparql.enable = true;
    };
    samba-wsdd = {
      enable = true;
      discovery = true;
    };
    displayManager.noctalia-greeter = {
      enable = true;
      settings = {
        session.default = "Umbriel";
        user.default = "hieronim";
        cursor = {
          theme = "Bibata-Modern-Classic";
          size = 24;
          path = pkgs.bibata-cursors;
        };
      };
    };
  };

  systemd.user.services.rog-control-center = {
    description = "rog-control-center";
    after = [ "umbriel-session.target" ];
    partOf = [ "umbriel-session.target" ];
    wantedBy = [ "umbriel-session.target" ];
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${lib.getExe' pkgs.glib.bin "gdbus"} wait --session --timeout 60 org.kde.StatusNotifierWatcher";
      ExecStart = "${lib.getExe' pkgs.asusctl "rog-control-center"} --autostart --background";
      Restart = "no";
      TimeoutStartSec = 65;
      TimeoutStopSec = 10;
    };
  };

  environment.systemPackages = [ pkgs.mangohud ];

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      inter
      source-serif
      noto-fonts
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font Mono" ];
      sansSerif = [
        "Inter"
        "Noto Sans"
      ];
      serif = [
        "Source Serif 4"
        "Noto Serif"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
