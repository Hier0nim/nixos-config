{pkgs, ...}:
# The wallpaper will be fetched from GitHub. I don't store my wallpapers locally.
let
  inherit (import ./options.nix) dotfilesDir;
  hyprpaperConf = pkgs.writeText "hyprpaper.conf" ''
    preload = ${dotfilesDir}/wallpapers/dark-cat-rosewater.png
    wallpaper = ,${dotfilesDir}/wallpapers/dark-cat-rosewater.png
  '';
  inherit (import ./scripts.nix {inherit pkgs;}) batteryNotificationScript rofiPowerMenuScript;
in {
  wayland.windowManager.hyprland = {
    enable = true;
    systemd = {
      enable = true;
      variables = ["--all"];
    };
    settings = {
      general = {
        layout = "master";
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "0x9399b2FF";
        "col.inactive_border" = "0x4488a3EE";
      };

      input = {
        kb_layout = "pl";
        kb_options = "grp:alt_shift_toggle,caps:escape";
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

      windowrule = [
        "float,udiskie"
        "float,title:^(Transmission)$"
        "float,title:^(Volume Control)$"
        "size 700 450,title:^(Volume Control)$"
        "size 700 450,title:^(Save As)$"
        "float,title:^(Library)$"
        "size 700 450,title:^(Page Info)$"
        "float,title:^(Page Info)$"
      ];
      windowrulev2 = [
        "float,class:^(pavucontrol)$"
        "float,class:^(file_progress)$"
        "float,class:^(confirm)$"
        "float,class:^(.protonvpn-app-wrapped)$"
        "float,class:^(.blueman-manager-wrapped)$"
        "float,class:^(dialog)$"
        "float,class:^(download)$"
        "float,class:^(notification)$"
        "float,class:^(nm-connection-editor)$"
        "float,title:^(File Operation Progress)$"
        "float,title:^(Open File)$"
        "float,title:^(Save As)$"
      ];

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

      # Using the Super key (windows button) as the main mod.
      "$mainMod" = "SUPER";

      bind =
        [
          # Launch apps
          "$mainMod,        b,   exec,   ${pkgs.librewolf}/bin/librewolf"
          "$mainMod,        d,   exec,   ${pkgs.vesktop}/bin/vesktop"
          "$mainMod,        e,   exec,   ${pkgs.emote}/bin/emote"
          "$mainMod,        f,   exec,   ${pkgs.nautilus}/bin/nautilus"
          "$mainMod,        i,   exec,   ${pkgs.loupe}/bin/loupe"
          "$mainMod,        k,   exec,   ${pkgs.keepassxc}/bin/keepassxc"
          "$mainMod,        p,   exec,   ${rofiPowerMenuScript}/bin/script"
          "$mainMod,        r,   exec,   ${pkgs.rofi-wayland}/bin/rofi -show drun -show-icons"
          "$mainMod,        s,   exec,   ${pkgs.spotify}/bin/spotify"
          "$mainMod,        x,   exec,   hyprlock" # Make sure you have Hyprlock installed. There's an official flake for it. See /flake.nix
          "$mainMod,   return,   exec,   [float;tile] ${pkgs.wezterm}/bin/wezterm start --always-new-process"
          "$mainMod SHIFT,  b,   exec,   ${batteryNotificationScript}/bin/script"
          "$mainMod SHIFT, F5,   exec,   ${pkgs.brightnessctl}/bin/brightnessctl s 0"
          "$mainMod SHIFT,  a,   exec,   ${pkgs.grimblast}/bin/grimblast --notify copysave area ~/Pictures/Screenshots/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
          "$mainMod SHIFT,  s,   exec,   ${pkgs.grimblast}/bin/grimblast --notify copysave screen ~/Pictures/Screenshots/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"

          # Brightness control
          # ",$XF86MonBrightnessUp,   exec, ${pkgs.brightnessctl}/bin/brightnessctl s +10%"
          # ",$XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl s 10%-"
          "$mainMod SHIFT, F3,   exec, ${pkgs.brightnessctl}/bin/brightnessctl s +10%"
          "$mainMod SHIFT, F4,   exec, ${pkgs.brightnessctl}/bin/brightnessctl s 10%-"

          # Control media players.
          ",XF86AudioPlay,  exec, ${pkgs.playerctl}/bin/playerctl play-pause"
          ",XF86AudioPause, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
          ",XF86AudioNext,  exec, ${pkgs.playerctl}/bin/playerctl next"
          ",XF86AudioPrev,  exec, ${pkgs.playerctl}/bin/playerctl previous"

          # Close a window or quit Hyprland.
          "$mainMod, Q, killactive,"
          "$mainMod SHIFT, M, exit,"

          # Toggle window states.
          "$mainMod SHIFT, t, togglefloating,"
          "$mainMod SHIFT, f, fullscreen,"

          # Move focus from one window to another.
          "$mainMod, h, movefocus, l"
          "$mainMod, l, movefocus, r"
          "$mainMod, k, movefocus, u"
          "$mainMod, j, movefocus, d"

          # Move window to either the left, right, top, or bottom.
          "$mainMod SHIFT,  h, movewindow, l"
          "$mainMod SHIFT,  l, movewindow, r"
          "$mainMod SHIFT,  k, movewindow, u"
          "$mainMod SHIFT,  j, movewindow, d"
        ]
        # WTF is this? I don't understand Nix code. 😿
        ++ map (n: "$mainMod SHIFT, ${toString n}, movetoworkspace, ${
          toString (
            if n == 0
            then 10
            else n
          )
        }") [1 2 3 4 5 6 7 8 9 0]
        ++ map (n: "$mainMod, ${toString n}, workspace, ${
          toString (
            if n == 0
            then 10
            else n
          )
        }") [1 2 3 4 5 6 7 8 9 0];

      binde = [
        # Move windows.
        "$mainMod SHIFT, h, moveactive, -20 0"
        "$mainMod SHIFT, l, moveactive, 20 0"
        "$mainMod SHIFT, k, moveactive, 0 -20"
        "$mainMod SHIFT, j, moveactive, 0 20"

        # Control the volume.
        ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute,        exec, wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle"

        # Resize windows.
        "$mainMod CTRL, l, resizeactive, 30 0"
        "$mainMod CTRL, h, resizeactive, -30 0"
        "$mainMod CTRL, k, resizeactive, 0 -10"
        "$mainMod CTRL, j, resizeactive, 0 10"
      ];

      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging.
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      exec-once = [
        "${pkgs.hyprpaper}/bin/hyprpaper -c ${hyprpaperConf}"
        "${pkgs.waybar}/bin/waybar"

        # Please see home/gtk.nix before modifying the line below. It actually sets the cursor to Bibata-Modern-Ice.
        "hyprctl setcursor default 24"
      ];
    };
  };
}
