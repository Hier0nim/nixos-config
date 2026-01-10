{ cosmicLib, ... }:
let
  # inherit (cosmicLib) mkDefault;
  inherit (cosmicLib.cosmic) mkRON;
in
{
  # Touchpad configuration
  wayland.desktopManager.cosmic.compositor = {
    input_touchpad = {
      state = mkRON "enum" "Enabled";

      acceleration = mkRON "optional" {
        profile = mkRON "optional" (mkRON "enum" "Adaptive");
        speed = 0.2;
      };

      click_method = mkRON "optional" (mkRON "enum" "Clickfinger");

      disable_while_typing = mkRON "optional" true;

      middle_button_emulation = mkRON "optional" true;

      map_to_output = mkRON "optional" "Active";

      scroll_config = mkRON "optional" {
        method = mkRON "optional" (mkRON "enum" "TwoFinger");
        natural_scroll = mkRON "optional" true;
        scroll_button = mkRON "optional" 2;
        scroll_factor = mkRON "optional" 1.0;
      };

      tap_config = mkRON "optional" {
        button_map = mkRON "optional" (cosmicLib.cosmic.mkRON "enum" "LeftRightMiddle");
        drag = true;
        drag_lock = true;
        enabled = true;
      };
    };
  };
}
