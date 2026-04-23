{
  boot = {
    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "systemd.show_status=false"
      "rd.systemd.show_status=false"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
    ];
    plymouth = {
      enable = true;
      # theme = lib.mkForce "hexagon_hud";
      # themePackages = [
      #   (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "hexagon_hud" ]; })
      # ];

      theme = "bgrt";
      #
      # extraConfig = ''
      #   ShowDelay=5
      # '';
    };
  };
  services.hardware.bolt.enable = true;
}
