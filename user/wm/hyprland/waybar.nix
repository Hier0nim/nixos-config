{ pkgs, settings, ... }:
{
  programs.waybar = {
    enable = true;
    settings.mainBar = {
      reload_style_on_change = true;
      layer = "top";
      position = "left";
      # height = 5;
      width = 50;
      margin-top = 5;
      margin-bottom = 5;
      margin-left = 0;
      margin-right = 5;
      fix-centered = true;
      modules-left = [
        "custom/launcher"
        "clock"
      ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [
        "group/brightness"
        "group/audio"
        "battery"
        "tray"
      ];

      "hyprland/workspaces" = {
        active-only = false;
        disable-scroll = false;
        format = "{icon}";
        on-click = "activate";
        format-icons = {
          "1" = "1";
          "2" = "2";
          "3" = "3";
          "4" = "4";
          "5" = "5";
          "6" = "6";
          "7" = "7";
          "8" = "8";
          "9" = "󰭻";
          "10" = " ";
          sort-by-number = true;
        };
      };

      tray = {
        icon-size = 21;
        spacing = 10;
      };

      clock = {
        format = "{:%H\n%M}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        tooltip = "true";
        calendar = {
          mode = "month";
          mode-mon-col = 3;
          weeks-pos = "right";
          on-scroll = 1;
          on-click-right = "mode";
          format = {
            today = "<span color='#a6e3a1'><b><u>{}</u></b></span>";
          };
        };
      };

      "group/brightness" = {
        orientation = "inherit";
        drawer = {
          transition-duration = 500;
          transition-left-to-right = false;
        };
        modules = [
          "backlight"
          "backlight/slider"
        ];
      };

      "backlight/slider" = {
        min = 5;
        max = 100;
        orientation = "vertical";
        device = "intel_backlight";
      };

      backlight = {
        device = "intel_backlight";
        format = "{icon}";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
        ];
        on-scroll-down = "brightnessctl s 5%-";
        on-scroll-up = "brightnessctl s +5%";
        tooltip = true;
        tooltip-format = "Brightness: {percent}% ";
        smooth-scrolling-threshol = 1;
      };

      cpu = {
        format = " {usage}%";
        format-alt = "  {avg_frequency} GHz";
        interval = 1;
      };

      "group/audio" = {
        orientation = "inherit";
        drawer = {
          "transition-duration" = 500;
          "transition-left-to-right" = false;
        };
        modules = [
          "pulseaudio"
          "pulseaudio/slider"
        ];
      };

      pulseaudio = {
        format = "{icon}";
        format-bluetooth = "{icon}";
        tooltip-forma = "{volume}% {icon} | {desc}";
        format-muted = "󰖁";
        format-icons = {
          headphones = "󰋌";
          handsfree = "󰋌";
          headset = "󰋌";
          phone = "";
          portable = "";
          car = " ";
          default = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
        };
        on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
      };

      "pulseaudio/slider" = {
        min = 0;
        max = 140;
        orientation = "vertical";
      };

      battery = {
        rotate = 270;
        states = {
          good = 95;
          warning = 30;
          critical = 15;
        };
        format = "{icon}";
        format-charging = "<b>{icon}</b>";
        format-full = "<span color='#82A55F'><b>{icon}</b></span>";
        format-warning = "<span color='#FAB387'><b>{icon}</b></span>";
        format-critical = "<span color='#F38BA8'><b>{icon}</b></span>";
        format-icons = [
          "󰂃"
          "󰁺"
          "󰁻"
          "󰁼"
          "󰁽"
          "󰁾"
          "󰁿"
          "󰂀"
          "󰂁"
          "󰂂"
          "󰁹"
        ];
        tooltip-format = "{timeTo} {capacity} % | {power} W";
      };

      "custom/launcher" = {
        format = " ";
        on-click = "pkill rofi || ${pkgs.rofi-wayland}/bin/rofi -show drun -show-icons";
        tooltip = "false";
      };
    };

    style =
      let
        custom = {
          font = "${settings.font}";
          font_size = "15px";
          font_weight = "bold";
        };
      in
      ''
        * {
          font-family: ${custom.font};
          font-size: ${custom.font_size};
          font-weight: ${custom.font_weight};
          min-height: 0;
        }

        #waybar {
          background: transparent;
          color: @text;
          background-color: @base;
          border-radius: 7px;
          /* border: 2px solid @blue; */
          border: 2px solid @overlay1;
          padding: 10px 0px;
        }

        #workspaces button{
          color: @lavender;
          transition: all 0.2s ease-out; /* Smooth transition for state changes */
        }

        #workspaces button:hover,
        #workspaces button.active {
          box-shadow: inherit;
          text-shadow: inherit;
          color: @pink;
          border: 2px solid @pink;
          background: alpha(darker(@overlay1), 0.5);
          padding: 8px 0px; /* Increase padding to enlarge the button */
        }

        .modules-left{
          margin: 6px 6px 6px 6px;
          border-radius: 4px;
          background: alpha(darker(@overlay1), 0.3);
        }

        .modules-right,
        .modules-center {
          margin: 6px 6px 6px 6px;
        }

        #tray,
        #backlight,
        #battery,
        #workspaces button,
        #pulseaudio {
          margin: 2px 2px 4px 2px;
          padding: 4px 0px; /* Increase padding to enlarge the button */
          color: @lavender;
          border-radius: 4px;
          background: alpha(darker(@overlay1), 0.3);
        }

        #battery {
          padding: 4px 0px;
        }

        #clock,
        #custom-launcher {
          font-size: 1.6rem;
          color: @lavender;
        }

        #backlight-slider slider,
        #pulseaudio-slider slider {
          background-color: transparent;
          box-shadow: none;
        }

        #backlight-slider trough,
        #pulseaudio-slider trough {
          margin-top: 4px;
          min-width: 6px;
          min-height: 60px;
          border-radius: 8px;
          background-color: alpha(@background, 0.6);
        }

        #backlight-slider highlight,
        #pulseaudio-slider highlight {
          border-radius: 8px;
          background-color: lighter(@active);
        }

        @define-color rosewater #f5e0dc;
        @define-color flamingo #f2cdcd;
        @define-color pink #f5c2e7;
        @define-color mauve #cba6f7;
        @define-color red #f38ba8;
        @define-color maroon #eba0ac;
        @define-color peach #fab387;
        @define-color yellow #f9e2af;
        @define-color green #a6e3a1;
        @define-color teal #94e2d5;
        @define-color sky #89dceb;
        @define-color sapphire #74c7ec;
        @define-color blue #89b4fa;
        @define-color lavender #b4befe;
        @define-color text #cdd6f4;
        @define-color subtext1 #bac2de;
        @define-color subtext0 #a6adc8;
        @define-color overlay2 #9399b2;
        @define-color overlay1 #7f849c;
        @define-color overlay0 #6c7086;
        @define-color surface2 #585b70;
        @define-color surface1 #45475a;
        @define-color surface0 #313244;
        @define-color base #1e1e2e;
        @define-color mantle #181825;
        @define-color crust #11111b;
      '';
  };
}
