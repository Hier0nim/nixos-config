{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  dmsIpc =
    target: function: args:
    [
      "dms"
      "ipc"
      "call"
      target
      function
    ]
    ++ args;
  dmsToggle = title: target: function: {
    hotkey-overlay.title = title;
    action.spawn = dmsIpc target function [ ];
  };
  dmsToggleWithArgs = title: target: function: args: {
    hotkey-overlay.title = title;
    action.spawn = dmsIpc target function args;
  };
  dmsLocked =
    target: function: args:
    hidden
    // {
      allow-when-locked = true;
      action.spawn = dmsIpc target function args;
    };
  niriFloatSticky = inputs.niri-float-sticky.packages.${pkgs.stdenv.hostPlatform.system}.default;
  dmsTheme = builtins.fromJSON (builtins.readFile ./themes/kanagawa-paper/theme.json);
  dmsColors = dmsTheme.dark;
  hidden = {
    hotkey-overlay.hidden = true;
  };
in
{
  imports = [
    inputs.niri.homeModules.niri
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri;

    settings = {
      environment = {
        QT_QPA_PLATFORMTHEME = "qt6ct";
        QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
      };

      spawn-at-startup = [
        {
          command = [
            (lib.getExe niriFloatSticky)
            "-title"
            "(?i)(picture[- ]in[- ]picture|\\bpip\\b)"
          ];
        }
      ];

      xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
      screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      input = {
        keyboard = {
          xkb.layout = "pl";
          repeat-delay = 600;
          repeat-rate = 25;
          track-layout = "global";
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
      };

      layout = {
        gaps = 5;
        background-color = "transparent";
        border = {
          enable = true;
          active.color = dmsColors.primary;
          inactive.color = dmsColors.outline;
          urgent.color = dmsColors.error;
        };
      };

      workspaces = {
        "1" = { };
        "2" = { };
        "3" = { };
        "4" = { };
        "5" = { };
        "6" = { };
        "7" = { };
        "8" = { };
        "9" = { };
      };

      overview.workspace-shadow.enable = false;

      prefer-no-csd = true;

      debug = {
        honor-xdg-activation-with-invalid-serial = true;
      };

      hotkey-overlay = {
        skip-at-startup = true;
        hide-not-bound = true;
      };

      window-rules = [
        {
          matches = [
            { title = "(?i)(picture[- ]in[- ]picture|\\bpip\\b)"; }
          ];
          default-column-width.proportion = 0.25;
          default-floating-position = {
            relative-to = "bottom-right";
            x = 24;
            y = 24;
          };
          default-window-height.proportion = 0.25;
          open-floating = true;
        }
        {
          geometry-corner-radius = {
            top-left = 10.0;
            top-right = 10.0;
            bottom-right = 10.0;
            bottom-left = 10.0;
          };
          clip-to-geometry = true;
        }
      ];

      layer-rules = [
        {
          matches = [
            { namespace = "^quickshell$"; }
          ];
          place-within-backdrop = true;
        }
        {
          matches = [
            { namespace = "dms:blurwallpaper"; }
          ];
          place-within-backdrop = true;
        }
      ];

      binds = {
        "Mod+Space" = dmsToggle "Open launcher" "spotlight" "toggle";
        "Mod+S" = dmsToggle "Open control center" "control-center" "toggle";
        "Mod+Comma" = dmsToggle "Open settings" "settings" "toggle";
        "Mod+Shift+Comma" = dmsToggleWithArgs "Open bar settings" "settings" "openWith" [ "dankbar" ];
        "Mod+Ctrl+L" = dmsToggle "Lock screen" "lock" "lock";
        "Mod+Ctrl+E" = dmsToggle "Open session menu" "powermenu" "toggle";
        "Mod+B" = dmsToggleWithArgs "Open dashboard" "dash" "open" [ "overview" ];
        "Mod+Slash" = dmsToggle "Open system monitor" "processlist" "focusOrToggle";
        "Mod+V" = dmsToggle "Open clipboard launcher" "clipboard" "toggle";
        "Mod+P" = dmsToggle "Open notepad" "notepad" "toggle";
        "Mod+N" = dmsToggle "Toggle notification history" "notifications" "toggle";
        "Mod+Shift+N" = dmsToggle "Toggle do not disturb" "notifications" "toggleDoNotDisturb";
        "Mod+Ctrl+I" = dmsToggle "Toggle idle inhibitor" "inhibit" "toggle";
        "Mod+Shift+T" = dmsToggle "Toggle dark mode" "theme" "toggle";

        "Mod+Shift+Slash" = hidden // {
          action.show-hotkey-overlay = { };
        };

        "XF86AudioRaiseVolume" = dmsLocked "audio" "increment" [ "3" ];
        "XF86AudioLowerVolume" = dmsLocked "audio" "decrement" [ "3" ];
        "XF86AudioMute" = dmsLocked "audio" "mute" [ ];
        "XF86AudioMicMute" = dmsLocked "audio" "micmute" [ ];
        "XF86AudioPause" = dmsLocked "mpris" "playPause" [ ];
        "XF86AudioPlay" = dmsLocked "mpris" "playPause" [ ];
        "XF86AudioPrev" = dmsLocked "mpris" "previous" [ ];
        "XF86AudioNext" = dmsLocked "mpris" "next" [ ];
        "Ctrl+XF86AudioRaiseVolume" = dmsLocked "mpris" "increment" [ "3" ];
        "Ctrl+XF86AudioLowerVolume" = dmsLocked "mpris" "decrement" [ "3" ];
        "XF86MonBrightnessUp" = dmsLocked "brightness" "increment" [
          "5"
          ""
        ];
        "XF86MonBrightnessDown" = dmsLocked "brightness" "decrement" [
          "5"
          ""
        ];

        "Mod+T" = hidden // {
          action.spawn = [ (lib.getExe pkgs.ghostty) ];
        };
        "Mod+Q" = hidden // {
          repeat = false;
          action.close-window = { };
        };
        "Mod+O" = hidden // {
          repeat = false;
          action.toggle-overview = { };
        };
        "Mod+Tab" = hidden // {
          repeat = false;
          action.toggle-overview = { };
        };

        "Mod+Left" = hidden // {
          action.focus-column-left = { };
        };
        "Mod+Down" = hidden // {
          action.focus-window-down = { };
        };
        "Mod+Up" = hidden // {
          action.focus-window-up = { };
        };
        "Mod+Right" = hidden // {
          action.focus-column-right = { };
        };
        "Mod+H" = hidden // {
          action.focus-column-left = { };
        };
        "Mod+J" = hidden // {
          action.focus-window-down = { };
        };
        "Mod+K" = hidden // {
          action.focus-window-up = { };
        };
        "Mod+L" = hidden // {
          action.focus-column-right = { };
        };

        "Mod+Shift+Left" = hidden // {
          action.move-column-left = { };
        };
        "Mod+Shift+Down" = hidden // {
          action.move-window-down = { };
        };
        "Mod+Shift+Up" = hidden // {
          action.move-window-up = { };
        };
        "Mod+Shift+Right" = hidden // {
          action.move-column-right = { };
        };
        "Mod+Shift+H" = hidden // {
          action.move-column-left = { };
        };
        "Mod+Shift+J" = hidden // {
          action.move-window-down = { };
        };
        "Mod+Shift+K" = hidden // {
          action.move-window-up = { };
        };
        "Mod+Shift+L" = hidden // {
          action.move-column-right = { };
        };

        "Mod+Alt+Left" = hidden // {
          action.focus-monitor-left = { };
        };
        "Mod+Alt+Down" = hidden // {
          action.focus-monitor-down = { };
        };
        "Mod+Alt+Up" = hidden // {
          action.focus-monitor-up = { };
        };
        "Mod+Alt+Right" = hidden // {
          action.focus-monitor-right = { };
        };
        "Mod+Alt+H" = hidden // {
          action.focus-monitor-left = { };
        };
        "Mod+Alt+J" = hidden // {
          action.focus-monitor-down = { };
        };
        "Mod+Alt+K" = hidden // {
          action.focus-monitor-up = { };
        };
        "Mod+Alt+L" = hidden // {
          action.focus-monitor-right = { };
        };

        "Mod+Page_Down" = hidden // {
          action.focus-workspace-down = { };
        };
        "Mod+Page_Up" = hidden // {
          action.focus-workspace-up = { };
        };
        "Mod+U" = hidden // {
          action.focus-workspace-down = { };
        };
        "Mod+I" = hidden // {
          action.focus-workspace-up = { };
        };

        "Mod+Alt+Shift+Left" = hidden // {
          action.move-column-to-monitor-left = { };
        };
        "Mod+Alt+Shift+Down" = hidden // {
          action.move-column-to-monitor-down = { };
        };
        "Mod+Alt+Shift+Up" = hidden // {
          action.move-column-to-monitor-up = { };
        };
        "Mod+Alt+Shift+Right" = hidden // {
          action.move-column-to-monitor-right = { };
        };
        "Mod+Alt+Shift+H" = hidden // {
          action.move-column-to-monitor-left = { };
        };
        "Mod+Alt+Shift+J" = hidden // {
          action.move-column-to-monitor-down = { };
        };
        "Mod+Alt+Shift+K" = hidden // {
          action.move-column-to-monitor-up = { };
        };
        "Mod+Alt+Shift+L" = hidden // {
          action.move-column-to-monitor-right = { };
        };

        "Mod+R" = hidden // {
          action.switch-preset-column-width = { };
        };
        "Mod+Shift+R" = hidden // {
          action.switch-preset-column-width-back = { };
        };
        "Mod+F" = hidden // {
          action.maximize-column = { };
        };
        "Mod+Shift+F" = hidden // {
          action.fullscreen-window = { };
        };
        "Mod+F11" = hidden // {
          action.fullscreen-window = { };
        };
        "Mod+C" = hidden // {
          action.center-column = { };
        };
        "Mod+G" = hidden // {
          action.toggle-window-floating = { };
        };
        "Mod+W" = hidden // {
          action.toggle-column-tabbed-display = { };
        };

        "Mod+Minus" = hidden // {
          action.set-column-width = "-10%";
        };
        "Mod+Equal" = hidden // {
          action.set-column-width = "+10%";
        };
        "Mod+Shift+Minus" = hidden // {
          action.set-window-height = "-10%";
        };
        "Mod+Shift+Equal" = hidden // {
          action.set-window-height = "+10%";
        };

        "Mod+Shift+S" = hidden // {
          action.screenshot = { };
        };
        "Ctrl+Mod+Shift+S" = hidden // {
          action.screenshot-screen = { };
        };
        "Alt+Mod+Shift+S" = hidden // {
          action.screenshot-window = { };
        };
        "Mod+Escape" = hidden // {
          allow-inhibiting = false;
          action.toggle-keyboard-shortcuts-inhibit = { };
        };
        "Ctrl+Alt+Delete" = hidden // {
          action.quit = { };
        };
      }
      // builtins.listToAttrs (
        builtins.concatLists (
          map
            (
              workspace:
              let
                number = toString workspace;
              in
              [
                {
                  name = "Mod+${number}";
                  value = hidden // {
                    action.focus-workspace = workspace;
                  };
                }
                {
                  name = "Mod+Shift+${number}";
                  value = hidden // {
                    action.move-window-to-workspace = workspace;
                  };
                }
                {
                  name = "Mod+Ctrl+Shift+${number}";
                  value = hidden // {
                    action.move-column-to-workspace = workspace;
                  };
                }
              ]
            )
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
            ]
        )
      );
    };
  };
}
