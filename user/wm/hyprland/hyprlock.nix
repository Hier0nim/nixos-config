{ settings, ... }:
let
  placeholderAndTimeColor = "rgb(205, 214, 244)";
in
{
  programs.hyprlock.enable = true;
  programs.hyprlock.settings = {
    path = "screenshot";
    general = {
      grace = 0;
      ignore_empty_input = true;
    };

    background = {
      path = "screenshot";
      blur_passes = 3;
      blur_size = 10;
      brightness = 1.0;
      contrast = 1.0;
      noise = 2.0e-2;
    };

    input-field = {
      monitor = "";
      size = "250, 50";
      outline_thickness = 0;
      dots_size = 0.26;
      inner_color = placeholderAndTimeColor;
      dots_spacing = 0.64;
      dots_center = true;
      fade_on_empty = true;
      placeholder_text = "<i>Password...</i>";
      hide_input = false;
      check_color = "rgb(40, 200, 250)";
      position = "0, 50";
      halign = "center";
      valign = "bottom";
    };
  };
  programs.hyprlock.extraConfig = ''
    label {
        monitor =
        text = cmd[update:1000] echo "<b><big> $(date +"%H:%M") </big></b>"
        color = "${placeholderAndTimeColor}";

        font_size = 64
        font_family = ${settings.font} 10

        position = 0, -70
        halign = center
        valign = center
    }

    label {
        monitor =
        text = cmd[update:18000000] echo "<b> "$(date +'%A, %-d %B %Y')" </b>"
        color = "${placeholderAndTimeColor}";

        font_size = 24
        font_family = ${settings.font} 10

        position = 0, -120
        halign = center
        valign = center
    }
  '';
}
