# If you'd like to change the font, see system/options.nix
# There's nothing much to edit here.
# We will use this to set the default font system-wide.
let
  inherit (import ./options.nix) fontName;
in {
  fonts = {
    enableDefaultPackages = true;
    fontconfig.defaultFonts = rec {
      monospace = ["${fontName}"];
      sansSerif = ["${fontName}"];
      serif = sansSerif;
    };
  };
}
