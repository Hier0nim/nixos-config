{
  config,
  cosmicLib,
  pkgs,
  ...
}:
let
  inherit (cosmicLib.cosmic) importRON mkRON;
in
{
  home.packages = with pkgs; [
    inter
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    papirus-icon-theme
  ];

  wayland.desktopManager.cosmic = {
    appearance = {
      theme = {
        dark = importRON ./Kanagawa.ron;
        mode = "dark";
      };

      toolkit = {
        apply_theme_global = true;
        icon_theme = "Papirus-Dark";

        interface_font = {
          family = "Inter";
          stretch = mkRON "enum" "Normal";
          style = mkRON "enum" "Normal";
          weight = mkRON "enum" "Normal";
        };

        monospace_font = {
          family = "JetBrainsMono Nerd Font Mono";
          stretch = mkRON "enum" "Normal";
          style = mkRON "enum" "Normal";
          weight = mkRON "enum" "Normal";
        };
      };
    };

    wallpapers = [
      {
        filter_by_theme = true;
        filter_method = mkRON "enum" "Lanczos";
        output = "all";
        rotation_frequency = 600;
        sampling_method = mkRON "enum" "Alphanumeric";

        scaling_mode = mkRON "enum" "Stretch";

        # Always quote the path string:
        source = mkRON "enum" {
          variant = "Path";
          value = [
            "${config.home.homeDirectory}/Projects/nixos-config/home/common/desktop-environments/wallpapers/koi.png"
          ];
        };
      }
    ];
  };
}
