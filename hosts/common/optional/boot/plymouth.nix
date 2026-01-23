{
  boot = {
    kernelParams = [
      "quiet"
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
