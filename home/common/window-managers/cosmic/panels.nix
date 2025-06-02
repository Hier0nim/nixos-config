{ cosmicLib, ... }:
let
  inherit (cosmicLib.cosmic) mkRON;
in
{
  wayland.desktopManager.cosmic.panels = [
    {
      anchor = mkRON "enum" "Left";
      anchor_gap = true;
      autohide = mkRON "optional" null;
      background = mkRON "enum" "ThemeDefault";
      expand_to_edges = true;
      name = "Panel";
      opacity = 1.0;
      output = mkRON "enum" "All";
      plugins_center = mkRON "optional" [ "com.system76.CosmicAppletWorkspaces" ];

      plugins_wings = mkRON "optional" (
        mkRON "tuple" [
          [ "com.system76.CosmicAppletTime" ]
          [
            "com.system76.CosmicAppletStatusArea"
            "com.system76.CosmicAppletTiling"
            "com.system76.CosmicAppletAudio"
            "com.system76.CosmicAppletNetwork"
            "com.system76.CosmicAppletBluetooth"
            "com.system76.CosmicAppletNotifications"
            "com.system76.CosmicAppletBattery"
            "com.system76.CosmicAppletPower"
          ]
        ]
      );

      size = mkRON "enum" "S";
    }
  ];
}
