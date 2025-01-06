{ pkgs, ... }:
let
  inherit (import ./scripts.nix { inherit pkgs; }) batteryNotificationScript rofiPowerMenuScript;
in
{
  wayland.windowManager.hyprland.settings = {
    "$mainMod" = "SUPER";

    # Mouse bindings.
    bindm = [
      "$mainMod, mouse:272, movewindow"
      "$mainMod, mouse:273, resizewindow"
    ];

    bindl = [
      # trigger when the switch is turning off
      ", switch:off:Lid Switch,exec,hyprctl keyword monitor \"eDP-1, 1920x1080, 0x0, 1.25\""
      # trigger when the switch is turning on
      ", switch:on:Lid Switch,exec,hyprctl keyword monitor \"eDP-1, disable\""
    ];

    binde = [
      # Move windows.
      "$mainMod SHIFT, h, moveactive, -20 0"
      "$mainMod SHIFT, semicolon, moveactive, 20 0"
      "$mainMod SHIFT, l, moveactive, 0 -20"
      "$mainMod SHIFT, k, moveactive, 0 20"

      # Control the volume.
      ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86AudioMute,        exec, wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle"

      # Resize windows.
      "$mainMod CTRL, p, resizeactive, 30 0"
      "$mainMod CTRL, u, resizeactive, -30 0"
      "$mainMod CTRL, o, resizeactive, 0 -10"
      "$mainMod CTRL, i, resizeactive, 0 10"
    ];

    bind =
      [
        # Launch apps
        "$mainMod,        b,   exec,   firefox"
        "$mainMod,        d,   exec,   ${pkgs.vesktop}/bin/vesktop"
        "$mainMod,        e,   exec,   nemo"
        "$mainMod,        p,   exec,   ${rofiPowerMenuScript}/bin/script"
        "$mainMod,        r,   exec,   ${pkgs.rofi-wayland}/bin/rofi -show drun -show-icons"
        "$mainMod,        w,   exec,   ${pkgs.rofi-wayland}/bin/rofi -show window -show-icons"
        "$mainMod,        m,   exec,   ${pkgs.spotify}/bin/spotify"
        "$mainMod,        x,   exec,   hyprlock" # Make sure you have Hyprlock installed. There's an official flake for it. See /flake.nix
        "$mainMod,   return,   exec,   wezterm start"
        "$mainMod SHIFT,  b,   exec,   ${batteryNotificationScript}/bin/script"
        "$mainMod SHIFT,  a,   exec,   ${pkgs.grimblast}/bin/grimblast --notify copysave area ~/Media/Pictures/Screenshots/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
        "$mainMod,        a,   exec,   ${pkgs.grimblast}/bin/grimblast --notify copysave screen ~/Media/Pictures/Screenshots/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
        "$mainMod,        v,   exec,   cliphist list | rofi -dmenu -p 'Cliphist' -theme-str 'listview { fixed-height: true; }' | cliphist decode | wl-copy"

        # Brightness control
        ",$XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl s 10%-"
        ",$XF86MonBrightnessUp,   exec, ${pkgs.brightnessctl}/bin/brightnessctl s +10%"
        "$mainMod SHIFT, F3,   exec, ${pkgs.brightnessctl}/bin/brightnessctl s 10%-"
        "$mainMod SHIFT, F4,   exec, ${pkgs.brightnessctl}/bin/brightnessctl s +10%"

        # Control media players.
        ",XF86AudioPlay,  exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        ",XF86AudioPause, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        ",XF86AudioNext,  exec, ${pkgs.playerctl}/bin/playerctl next"
        ",XF86AudioPrev,  exec, ${pkgs.playerctl}/bin/playerctl previous"

        "$mainMod SHIFT, F8,  exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        "$mainMod SHIFT, F8,  exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        "$mainMod SHIFT, F9,  exec, ${pkgs.playerctl}/bin/playerctl next"
        "$mainMod SHIFT, F7,  exec, ${pkgs.playerctl}/bin/playerctl previous"

        # Close a window or quit Hyprland.
        "$mainMod, Q, killactive,"
        "$mainMod SHIFT, M, exit,"

        # Toggle window states.
        "$mainMod SHIFT, t, togglefloating,"
        "$mainMod SHIFT, f, fullscreen,"

        # Move focus from one window to another.
        "$mainMod, j, movefocus, l"
        "$mainMod, semicolon, movefocus, r"
        "$mainMod, l, movefocus, u"
        "$mainMod, k, movefocus, d"

        "$mainMod CTRL, j, workspace, r-1"
        "$mainMod CTRL, semicolon, workspace, r+1"

        # Move window to either the left, right, top, or bottom.
        "$mainMod SHIFT,  j, movewindow, l"
        "$mainMod SHIFT,  semicolon, movewindow, r"
        "$mainMod SHIFT,  l, movewindow, u"
        "$mainMod SHIFT,  k, movewindow, d"

        # Move to next monitor
        "$mainMod SHIFT, u, movecurrentworkspacetomonitor, l"
        "$mainMod SHIFT, i, movecurrentworkspacetomonitor, r"

        # Lock screen
        "$mainMod, Escape, exec, hyprlock"

        # Special workspace
        "$mainMod, S, togglespecialworkspace"
        "$mainMod SHIFT, S, movetoworkspacesilent, special"

        # Move monitor focus.
        "$mainMod, TAB, focusmonitor, +1"
        "$mainMod SHIFT, TAB, focusmonitor, -1"

      ]
      ++ map (n: "$mainMod SHIFT, ${toString n}, movetoworkspace, ${toString (if n == 0 then 10 else n)}")
        [
          1
          2
          3
          4
          5
          6
          7
          8
          9
          0
        ]
      ++ map (n: "$mainMod, ${toString n}, workspace, ${toString (if n == 0 then 10 else n)}") [
        1
        2
        3
        4
        5
        6
        7
        8
        9
        0

      ];
  };
}
