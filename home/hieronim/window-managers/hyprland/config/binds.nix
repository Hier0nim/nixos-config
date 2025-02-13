{ pkgs, ... }:
let
  inherit (import ../scripts.nix { inherit pkgs; }) rofiPowerMenuScript;
in
{
  wayland.windowManager.hyprland.settings = {
    bind =
      let
        defaultApp =
          type: "${pkgs.gtk3}/bin/gtk-launch $(${pkgs.xdg-utils}/bin/xdg-mime query default ${type})";
        browser = defaultApp "x-scheme-handler/https";
        editor = defaultApp "text/plain";
        fileManager = defaultApp "inode/directory";
      in
      [
        # Compositor commands
        "SUPER, S, togglesplit"
        "SUPER, Space, togglefloating"
        "SUPER, Q, killactive"
        "SUPER, F, fullscreen"
        "SUPER, C, centerwindow"

        # Move focus
        "SUPER, left, movefocus, l"
        "SUPER, j, movefocus, l"
        "SUPER, right, movefocus, r"
        "SUPER, semicolon, movefocus, r"
        "SUPER, up, movefocus, u"
        "SUPER, l, movefocus, u"
        "SUPER, down, movefocus, d"
        "SUPER, k, movefocus, d"

        # Move windows
        "SUPER_SHIFT, left, movewindow, l"
        "SUPER_SHIFT, J, movewindow, l"
        "SUPER_SHIFT, right, movewindow, r"
        "SUPER_SHIFT, semicolon, movewindow, r"
        "SUPER_SHIFT, up, movewindow, u"
        "SUPER_SHIFT, K, movewindow, u"
        "SUPER_SHIFT, down, movewindow, d"
        "SUPER_SHIFT, K, movewindow, d"

        # Cycle through windows
        "ALT, Tab, cyclenext"
        "ALT, Tab, bringactivetotop"

        # Special workspaces
        "SUPER, grave, togglespecialworkspace, magic"
        "SUPER_SHIFT, grave, movetoworkspace, special:magic"

        # Cycle workspaces
        "SUPER, bracketleft, workspace, m-1"
        "SUPER, bracketright, workspace, m+1"

        # Cycle monitors
        "SUPER_SHIFT, bracketleft, focusmonitor, l"
        "SUPER_SHIFT, bracketright, focusmonitor, r"

        # Send focused workspace to left/right monitors
        "SUPER_ALT, bracketleft, movecurrentworkspacetomonitor, l"
        "SUPER_ALT, bracketright, movecurrentworkspacetomonitor, r"

        # Application Shortcuts
        "SUPER, Return, exec, wezterm"
        "SUPER, B, exec, ${browser}"
        "SUPER, E, exec, ${fileManager}"
        # "SUPER, N, exec, ${fileManager}"
        "CTRL_ALT, L, exec, pgrep hyprlock || hyprlock"
        "SUPER, M,   exec, ${pkgs.spotify}/bin/spotify"

        # Screenshot
        "SUPER Shift, S, exec, grimblast --notify copysave area"
        "SUPER_CTRL Shift, S, exec, grimblast --notify --cursor copysave output"
        "SUPER_ALT Shift, S, exec, grimblast --notify --cursor copysave screen"

        # Menus
        "SUPER, P, exec, ${rofiPowerMenuScript.outPath}"
        "SUPER, R, exec, ${pkgs.rofi-wayland}/bin/rofi -show drun -show-icons"
        "SUPER, V, exec, cliphist list | rofi -dmenu -p 'Cliphist' -theme-str 'listview { fixed-height: true; }' | cliphist decode | wl-copy"
      ]
      ++ builtins.concatLists (
        builtins.genList (
          x:
          let
            ws =
              let
                c = (x + 1) / 10;
              in
              builtins.toString (x + 1 - (c * 10));
          in
          [
            "SUPER, ${ws}, workspace, ${toString (x + 1)}"
            "SUPER_SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            "ALT_SHIFT, ${ws}, movetoworkspacesilent, ${toString (x + 1)}"
          ]
        ) 10
      );

    binde = [
      # Resize windows
      "SUPER_CTRL, left, resizeactive, -20 0"
      "SUPER_CTRL, J, resizeactive, -20 0"
      "SUPER_CTRL, right, resizeactive,  20 0"
      "SUPER_CTRL, semicolon, resizeactive,  20 0"
      "SUPER_CTRL, up, resizeactive,  0 -20"
      "SUPER_CTRL, L, resizeactive,  0 -20"
      "SUPER_CTRL, down, resizeactive,  0 20"
      "SUPER_CTRL, K, resizeactive,  0 20"

      # Move windows
      "SUPER_ALT, left, moveactive, -20 0"
      "SUPER_ALT, J, moveactive, -20 0"
      "SUPER_ALT, right, moveactive,  20 0"
      "SUPER_ALT, semicolon, moveactive,  20 0"
      "SUPER_ALT, up, moveactive,  0 -20"
      "SUPER_ALT, L, moveactive,  0 -20"
      "SUPER_ALT, down, moveactive,  0 20"
      "SUPER_ALT, K, moveactive,  0 20"
    ];

    bindr = [
    ];

    bindl = [
      # Toggle mute
      ",XF86AudioMute, exec, volumectl toggle-mute"
      ",XF86AudioMicMute, exec, volumectl toggle-mic-mute"

      # Toggle airplane mode
      ",XF86RFKill, exec, networkctl toggle-network"
    ];

    bindle = [
      # Audio control
      ",XF86AudioRaiseVolume, exec, volumectl up 5"
      ",XF86AudioLowerVolume, exec, volumectl down 5"

      # Brightness control
      ",XF86MonBrightnessUp, exec, lightctl up 5"
      ",XF86MonBrightnessDown, exec, lightctl down 5"
    ];

    # Mouse bindings
    bindm = [
      "SUPER, mouse:272, movewindow"
      "SUPER, mouse:273, resizewindow"
      "SUPER ALT, mouse:272, resizewindow"
    ];
  };
}
