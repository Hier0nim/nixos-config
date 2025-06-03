{ config, ... }:
{
  wayland.windowManager.hyprland.settings =
    let
      pointer = config.home.pointerCursor;
      inherit (config.theme.colorscheme) colors;
    in
    {
      env = [
        "CLUTTER_BACKEND,wayland"
        "GDK_BACKEND,wayland,x11,*"
        "SDL_VIDEODRIVER,wayland"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "QT_QPA_PLATFORM,wayland;xcb"
        "QT_QPA_PLATFORMTHEME,qt5ct"
        "QT_STYLE_OVERRIDE,kvantum"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "GTK_THEME,${config.gtk.theme.name}"
        "XCURSOR_THEME,${pointer.name}"
        "XCURSOR_SIZE,${toString pointer.size}"
      ];

      exec-once = [
        "hyprctl setcursor ${pointer.name} ${toString pointer.size}"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      general = {
        layout = "master";
        gaps_in = 5;
        gaps_out = 5;
        border_size = 2;
        "col.active_border" = "0xFF7f849c";
        "col.inactive_border" = "0x4488a3EE";

        resize_on_border = true;

        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = true;
      };

      decoration = {
        rounding = 5;
        shadow.color = "rgba(1a1a1aee)";
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        fullscreen_opacity = 1.0;
        blur.enabled = false;
      };

      animations = {
        enabled = true;
        first_launch_animation = true;

        bezier = [
          "easeOutQuart, 0.25, 1, 0.5, 1"
        ];

        animation = [
          "windows, 1, 3, easeOutQuart, slide"
          "layers, 1, 3, easeOutQuart, fade"
          "fade, 1, 3, easeOutQuart"
          "border, 1, 5, easeOutQuart"
          "workspaces, 1, 5, easeOutQuart, slide"
          "specialWorkspace, 1, 5, easeOutQuart, slidevert"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      master.new_status = "master";

      input = {
        kb_layout = "pl";
        follow_mouse = 1;
        force_no_accel = true;

        touchpad = {
          disable_while_typing = true;
          natural_scroll = true;
          tap-to-click = true;
          tap-and-drag = true;
          scroll_factor = 0.5;
          # accelSpeed = "-0.5";
        };
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_forever = true;
      };

      misc = {
        vrr = 1;
        enable_swallow = true;
        force_default_wallpaper = 0;
        new_window_takes_over_fullscreen = 2;
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
      };

      binds = {
        allow_workspace_cycles = true;
      };

      xwayland = {
        enabled = true;
        force_zero_scaling = true;
      };

      plugin = {
        hyprexpo = {
          columns = 3;
          gap_size = 4;
          bg_col = "rgb(${colors.black0})";
          enable_gesture = true;
          gesture_fingers = 3;
          gesture_distance = 300;
          gesture_positive = false;
        };
      };
    };
}
