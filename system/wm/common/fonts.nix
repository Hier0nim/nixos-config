{ settings, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    fontconfig.defaultFonts = rec {
      monospace = [ "${settings.font} Mono" ];
      sansSerif = [ "${settings.font}" ];
      serif = sansSerif;
    };
    packages = [
      settings.fontPkg
    ];
  };
}
