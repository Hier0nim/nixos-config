{ pkgs, settings, ... }:
let
  hyprpaperConf = pkgs.writeText "hyprpaper.conf" ''
    preload = ${settings.dotfilesDir}/user/wm/wallpapers/dark-cat-rosewater.png
    wallpaper = ,${settings.dotfilesDir}/user/wm/wallpapers/dark-cat-rosewater.png
  '';
in
{
  wayland.windowManager.hyprland.settings = {
    monitor = [
      "eDP-1, 1920x1080@144, 0x0, 1.25"
      ",preferred,auto,1"
    ];

    xwayland = {
      force_zero_scaling = true;
    };

    general = {
      layout = "master";
      gaps_in = 5;
      gaps_out = 10;
      border_size = 2;
      "col.active_border" = "0x9399b2FF";
      "col.inactive_border" = "0x4488a3EE";
    };

    input = {
      kb_layout = "${settings.layout}";
      touchpad = {
        natural_scroll = true;
        disable_while_typing = true;
      };

      repeat_rate = 40;
      repeat_delay = 250;
      force_no_accel = true;
      sensitivity = 0.3; # -1.0 - 1.0, 0 means no modification.
      follow_mouse = 1;
      numlock_by_default = true;
    };

    misc = {
      enable_swallow = true;
      force_default_wallpaper = 0;
      new_window_takes_over_fullscreen = 2;
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      animate_manual_resizes = true;
      animate_mouse_windowdragging = true;
    };

    decoration = {
      rounding = 7;
      "col.shadow" = "rgba(1a1a1aee)";
      active_opacity = 1.0;
      inactive_opacity = 1.0;
      fullscreen_opacity = 1.0;
      blur = {
        enabled = false;
        size = 4;
        passes = 2;

        brightness = 1;
        contrast = 1.3;
        ignore_opacity = true;
        noise = 1.17e-2;

        new_optimizations = true;
        xray = true;
      };
    };

    animations = {
      enabled = true;
      first_launch_animation = true;
      bezier = [
        "wind, 0.05, 0.9, 0.1, 1.05"
        "winIn, 0.1, 1.1, 0.1, 1.1"
        "winOut, 0.3, -0.3, 0, 1"
        "liner, 1, 1, 1, 1"
      ];
      animation = [
        "windows, 1, 6, wind, slide"
        "windowsIn, 1, 6, winIn, slide"
        "windowsOut, 1, 5, winOut, slide"
        "windowsMove, 1, 5, wind, slide"
        "border, 1, 1, liner"
        "borderangle, 1, 30, liner, loop"
        "fade, 1, 10, default"
        "workspaces, 1, 5, wind"
      ];
    };

    dwindle = {
      pseudotile = true;
      preserve_split = true;
    };
    master.new_status = "master";
    gestures.workspace_swipe = true;

    exec-once = [
      "hyprlock"
      "${pkgs.hyprpaper}/bin/hyprpaper -c ${hyprpaperConf}"
      "${pkgs.waybar}/bin/waybar"
      "wl-paste --type text --watch cliphist store"
      "wl-paste --type image --watch cliphist store"
    ];
  };
}
