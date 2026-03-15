{
  config,
  cosmicLib,
  ...
}:
let
  inherit (cosmicLib) getExe optionals;
  inherit (cosmicLib.cosmic) mkRON;
in
{
  wayland.desktopManager.cosmic.systemActions = mkRON "map" (
    optionals config.programs.ghostty.enable [
      {
        key = mkRON "enum" "Terminal";
        value = getExe config.programs.ghostty.package;
      }
    ]
  );

  wayland.desktopManager.cosmic.shortcuts = [
    {
      action = cosmicLib.cosmic.mkRON "enum" {
        value = [
          (cosmicLib.cosmic.mkRON "enum" "Screenshot")
        ];
        variant = "System";
      };
      key = "Super+Shift+S";
    }

    {
      action = mkRON "enum" "SwapWindow";
      key = "Super+E";
    }

  ]
  ++ optionals config.services.copyq.enable [
    # CopyQ toggle
    {
      action = mkRON "enum" {
        variant = "Spawn";
        value = [ "copyq toggle" ];
      };
      key = "Super+V";
    }
  ];
}
