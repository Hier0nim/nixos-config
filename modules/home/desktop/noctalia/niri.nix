{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  call = pkgs.lib.flip import {
    inherit
      inputs
      kdl
      docs
      binds
      settings
      ;
    inherit (pkgs) lib;
  };
  kdl = call "${inputs.niri}/kdl.nix";
  binds = call "${inputs.niri}/parse-binds.nix";
  docs = call "${inputs.niri}/generate-docs.nix";
  settings = call "${inputs.niri}/settings.nix";

  noctaliaShell = lib.getExe config.programs.noctalia-shell.package;
  monitorsFile = "${config.xdg.configHome}/niri/monitors.kdl";
  noctaliaFile = "${config.xdg.configHome}/niri/noctalia.kdl";

  niriConfig = [
    (kdl.leaf "include" noctaliaFile)
    (kdl.leaf "include" monitorsFile)
  ]
  ++ (settings.render config.programs.niri.settings);
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
      };

      spawn-at-startup = [
        {
          command = [ noctaliaShell ];
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

      debug = {
        honor-xdg-activation-with-invalid-serial = true;
      };

      hotkey-overlay = {
        skip-at-startup = true;
        hide-not-bound = true;
      };

      window-rules = [
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
            { namespace = "^noctalia-wallpaper.*"; }
          ];
          place-within-backdrop = true;
        }
      ];

      binds = {
        "Mod+Space" = {
          hotkey-overlay.title = "Open launcher";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "launcher"
            "toggle"
          ];
        };
        "Mod+S" = {
          hotkey-overlay.title = "Open control center";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "controlCenter"
            "toggle"
          ];
        };
        "Mod+Comma" = {
          hotkey-overlay.title = "Open settings";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "settings"
            "toggle"
          ];
        };
        "Mod+Shift+Comma" = {
          hotkey-overlay.title = "Open bar settings";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "settings"
            "openTab"
            "bar"
          ];
        };
        "Mod+Ctrl+L" = {
          hotkey-overlay.title = "Lock screen";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "lockScreen"
            "lock"
          ];
        };
        "Mod+Ctrl+E" = {
          hotkey-overlay.title = "Open session menu";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "sessionMenu"
            "toggle"
          ];
        };
        "Mod+B" = {
          hotkey-overlay.title = "Open calendar";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "calendar"
            "toggle"
          ];
        };
        "Mod+Slash" = {
          hotkey-overlay.title = "Open system monitor";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "systemMonitor"
            "toggle"
          ];
        };

        "Mod+V" = {
          hotkey-overlay.title = "Open clipboard launcher";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "launcher"
            "clipboard"
          ];
        };
        "Mod+P" = {
          hotkey-overlay.title = "Open command launcher";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "launcher"
            "command"
          ];
        };
        "Mod+Tab" = {
          hotkey-overlay.title = "Open window launcher";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "launcher"
            "windows"
          ];
        };
        "Mod+Shift+Slash" = {
          hotkey-overlay.hidden = true;
          action.show-hotkey-overlay = { };
        };

        "XF86AudioRaiseVolume" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "volume"
            "increase"
          ];
        };

        "XF86AudioLowerVolume" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "volume"
            "decrease"
          ];
        };

        "XF86AudioMute" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "volume"
            "muteOutput"
          ];
        };

        "XF86AudioMicMute" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "volume"
            "muteInput"
          ];
        };

        "XF86AudioPlay" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "media"
            "playPause"
          ];
        };

        "XF86AudioPrev" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "media"
            "previous"
          ];
        };

        "XF86AudioNext" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "media"
            "next"
          ];
        };

        "XF86MonBrightnessUp" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "brightness"
            "increase"
          ];
        };

        "XF86MonBrightnessDown" = {
          allow-when-locked = true;
          hotkey-overlay.hidden = true;
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "brightness"
            "decrease"
          ];
        };

        "Mod+N" = {
          hotkey-overlay.title = "Toggle notification history";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "notifications"
            "toggleHistory"
          ];
        };
        "Mod+Shift+N" = {
          hotkey-overlay.title = "Toggle do not disturb";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "notifications"
            "toggleDND"
          ];
        };
        "Mod+Ctrl+I" = {
          hotkey-overlay.title = "Toggle idle inhibitor";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "idleInhibitor"
            "toggle"
          ];
        };
        "Mod+Shift+T" = {
          hotkey-overlay.title = "Toggle dark mode";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "darkMode"
            "toggle"
          ];
        };
        "Mod+Ctrl+P" = {
          hotkey-overlay.title = "Cycle power profile";
          action.spawn = [
            noctaliaShell
            "ipc"
            "call"
            "powerProfile"
            "cycle"
          ];
        };

        "Mod+T" = {
          hotkey-overlay.hidden = true;
          action.spawn = [ (lib.getExe pkgs.ghostty) ];
        };

        "Mod+Q" = {
          hotkey-overlay.hidden = true;
          repeat = false;
          action.close-window = { };
        };

        "Mod+O" = {
          hotkey-overlay.hidden = true;
          repeat = false;
          action.toggle-overview = { };
        };

        "Mod+Left" = {
          hotkey-overlay.hidden = true;
          action.focus-column-left = { };
        };
        "Mod+Down" = {
          hotkey-overlay.hidden = true;
          action.focus-window-down = { };
        };
        "Mod+Up" = {
          hotkey-overlay.hidden = true;
          action.focus-window-up = { };
        };
        "Mod+Right" = {
          hotkey-overlay.hidden = true;
          action.focus-column-right = { };
        };

        "Mod+H" = {
          hotkey-overlay.hidden = true;
          action.focus-column-left = { };
        };
        "Mod+J" = {
          hotkey-overlay.hidden = true;
          action.focus-window-down = { };
        };
        "Mod+K" = {
          hotkey-overlay.hidden = true;
          action.focus-window-up = { };
        };
        "Mod+L" = {
          hotkey-overlay.hidden = true;
          action.focus-column-right = { };
        };

        "Mod+Shift+Left" = {
          hotkey-overlay.hidden = true;
          action.move-column-left = { };
        };
        "Mod+Shift+Down" = {
          hotkey-overlay.hidden = true;
          action.move-window-down = { };
        };
        "Mod+Shift+Up" = {
          hotkey-overlay.hidden = true;
          action.move-window-up = { };
        };
        "Mod+Shift+Right" = {
          hotkey-overlay.hidden = true;
          action.move-column-right = { };
        };

        "Mod+Shift+H" = {
          hotkey-overlay.hidden = true;
          action.move-column-left = { };
        };
        "Mod+Shift+J" = {
          hotkey-overlay.hidden = true;
          action.move-window-down = { };
        };
        "Mod+Shift+K" = {
          hotkey-overlay.hidden = true;
          action.move-window-up = { };
        };
        "Mod+Shift+L" = {
          hotkey-overlay.hidden = true;
          action.move-column-right = { };
        };

        "Mod+Alt+Left" = {
          hotkey-overlay.hidden = true;
          action.focus-monitor-left = { };
        };
        "Mod+Alt+Down" = {
          hotkey-overlay.hidden = true;
          action.focus-monitor-down = { };
        };
        "Mod+Alt+Up" = {
          hotkey-overlay.hidden = true;
          action.focus-monitor-up = { };
        };
        "Mod+Alt+Right" = {
          hotkey-overlay.hidden = true;
          action.focus-monitor-right = { };
        };

        "Mod+Alt+H" = {
          hotkey-overlay.hidden = true;
          action.focus-monitor-left = { };
        };
        "Mod+Alt+J" = {
          hotkey-overlay.hidden = true;
          action.focus-monitor-down = { };
        };
        "Mod+Alt+K" = {
          hotkey-overlay.hidden = true;
          action.focus-monitor-up = { };
        };
        "Mod+Alt+L" = {
          hotkey-overlay.hidden = true;
          action.focus-monitor-right = { };
        };

        "Mod+Page_Down" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace-down = { };
        };
        "Mod+Page_Up" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace-up = { };
        };
        "Mod+U" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace-down = { };
        };
        "Mod+I" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace-up = { };
        };

        "Mod+1" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 1;
        };
        "Mod+2" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 2;
        };
        "Mod+3" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 3;
        };
        "Mod+4" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 4;
        };
        "Mod+5" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 5;
        };
        "Mod+6" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 6;
        };
        "Mod+7" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 7;
        };
        "Mod+8" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 8;
        };
        "Mod+9" = {
          hotkey-overlay.hidden = true;
          action.focus-workspace = 9;
        };

        "Mod+Shift+1" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 1;
        };
        "Mod+Shift+2" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 2;
        };
        "Mod+Shift+3" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 3;
        };
        "Mod+Shift+4" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 4;
        };
        "Mod+Shift+5" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 5;
        };
        "Mod+Shift+6" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 6;
        };
        "Mod+Shift+7" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 7;
        };
        "Mod+Shift+8" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 8;
        };
        "Mod+Shift+9" = {
          hotkey-overlay.hidden = true;
          action.move-window-to-workspace = 9;
        };

        "Mod+Ctrl+Shift+1" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 1;
        };
        "Mod+Ctrl+Shift+2" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 2;
        };
        "Mod+Ctrl+Shift+3" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 3;
        };
        "Mod+Ctrl+Shift+4" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 4;
        };
        "Mod+Ctrl+Shift+5" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 5;
        };
        "Mod+Ctrl+Shift+6" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 6;
        };
        "Mod+Ctrl+Shift+7" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 7;
        };
        "Mod+Ctrl+Shift+8" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 8;
        };
        "Mod+Ctrl+Shift+9" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-workspace = 9;
        };

        "Mod+Alt+Shift+Left" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-monitor-left = { };
        };
        "Mod+Alt+Shift+Down" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-monitor-down = { };
        };
        "Mod+Alt+Shift+Up" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-monitor-up = { };
        };
        "Mod+Alt+Shift+Right" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-monitor-right = { };
        };

        "Mod+Alt+Shift+H" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-monitor-left = { };
        };
        "Mod+Alt+Shift+J" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-monitor-down = { };
        };
        "Mod+Alt+Shift+K" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-monitor-up = { };
        };
        "Mod+Alt+Shift+L" = {
          hotkey-overlay.hidden = true;
          action.move-column-to-monitor-right = { };
        };

        "Mod+R" = {
          hotkey-overlay.hidden = true;
          action.switch-preset-column-width = { };
        };
        "Mod+Shift+R" = {
          hotkey-overlay.hidden = true;
          action.switch-preset-column-width-back = { };
        };
        "Mod+F" = {
          hotkey-overlay.hidden = true;
          action.maximize-column = { };
        };
        "Mod+Shift+F" = {
          hotkey-overlay.hidden = true;
          action.fullscreen-window = { };
        };
        "Mod+F11" = {
          hotkey-overlay.hidden = true;
          action.fullscreen-window = { };
        };
        "Mod+C" = {
          hotkey-overlay.hidden = true;
          action.center-column = { };
        };
        "Mod+G" = {
          hotkey-overlay.hidden = true;
          action.toggle-window-floating = { };
        };
        "Mod+W" = {
          hotkey-overlay.hidden = true;
          action.toggle-column-tabbed-display = { };
        };

        "Mod+Minus" = {
          hotkey-overlay.hidden = true;
          action.set-column-width = "-10%";
        };
        "Mod+Equal" = {
          hotkey-overlay.hidden = true;
          action.set-column-width = "+10%";
        };
        "Mod+Shift+Minus" = {
          hotkey-overlay.hidden = true;
          action.set-window-height = "-10%";
        };
        "Mod+Shift+Equal" = {
          hotkey-overlay.hidden = true;
          action.set-window-height = "+10%";
        };

        "Mod+Shift+S" = {
          hotkey-overlay.hidden = true;
          action.screenshot = { };
        };
        "Ctrl+Mod+Shift+S" = {
          hotkey-overlay.hidden = true;
          action.screenshot-screen = { };
        };
        "Alt+Mod+Shift+S" = {
          hotkey-overlay.hidden = true;
          action.screenshot-window = { };
        };

        "Mod+Escape" = {
          allow-inhibiting = false;
          hotkey-overlay.hidden = true;
          action.toggle-keyboard-shortcuts-inhibit = { };
        };

        "Ctrl+Alt+Delete" = {
          hotkey-overlay.hidden = true;
          action.quit = { };
        };
      };
    };

    config = niriConfig;
  };

  xdg.configFile.niri-config.enable = lib.mkForce false;
  xdg.configFile."niri/config.kdl".text = kdl.serialize.nodes niriConfig;
}
