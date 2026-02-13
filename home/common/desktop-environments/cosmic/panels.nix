{ cosmicLib, ... }:
let
  inherit (cosmicLib.cosmic) mkRON;
in
{
  wayland.desktopManager.cosmic.panels = [
    {
      anchor = mkRON "enum" "Left";
      anchor_gap = true;
      margin = 4;
      autohide = mkRON "optional" null;
      background = mkRON "enum" "ThemeDefault";
      expand_to_edges = true;
      name = "Panel";
      opacity = 1.0;
      output = mkRON "enum" "All";
      plugins_center = mkRON "optional" [
        "com.system76.CosmicAppletWorkspaces"
      ];

      plugins_wings = mkRON "optional" (
        mkRON "tuple" [
          [
            "com.system76.CosmicAppletTime"
            "io.github.cosmic_utils.weather-applet"
            "dev.DBrox.CosmicPrivacyIndicator"
          ]
          [
            "com.system76.CosmicAppletStatusArea"
            # "io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager"
            "net.tropicbliss.CosmicExtAppletCaffeine"
            "com.system76.CosmicAppletTiling"
            "com.system76.CosmicAppletAudio"
            "com.system76.CosmicAppletNetwork"
            "com.system76.CosmicAppletBluetooth"
            "com.system76.CosmicAppletNetwork"
            "com.system76.CosmicAppletNotifications"
            "io.github.cosmic_utils.cosmic-ext-applet-external-monitor-brightness"
            "com.system76.CosmicAppletBattery"
            "com.system76.CosmicAppletPower"
          ]
        ]
      );

      size = mkRON "enum" "XS";
    }
  ];
}
