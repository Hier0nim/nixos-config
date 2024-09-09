{ inputs, config, lib, pkgs, userSettings, systemSettings, ... }:

{
  imports = [
    ../../app/wezterm.nix
    ./hyprpaper.nix
  ];

  gtk = {
    package = pkgs.quintom-cursor-theme;
    name = "Quintom_Ink";
    size = 36;
  };

  gtk.iconTheme = {
    package = pkgs.papirus-icon-theme;
    name = "Papirus-Dark";
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    plugins = [
      inputs.hyprgrass.packages.${pkgs.system}.default
    ];
    settings = { };
    extraConfig = ''
      exec-once = dbus-update-activation-environment --systemd DISPLAY XAUTHORITY WAYLAND_DISPLAY XDG_SESSION_DESKTOP=Hyprland XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland
      exec-once = hyprctl setcursor '' + config.gtk.cursorTheme.name + " " + builtins.toString config.gtk.cursorTheme.size + ''
    '';
    xwayland = { enable = true; };
    systemd.enable = true;
  };

  home.packages = (with pkgs; [
    waybar

    # notification daeom
    mako
    libnotify

    # launcher
    rofi-wayland

    libinput
    ]);

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}
