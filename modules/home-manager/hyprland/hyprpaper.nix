{ ... }: 

{
  # wayland.windowManager.hyprland.settings.exec-once =
  #   [ "${pkgs.hyprpaper}/bin/hyprpaper" ];

  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2.0;
      preload = [ "./wallpapers/nix." ];
      wallpaper = [ ",./wallpapers/nix.png" ];
    };
  };
}
