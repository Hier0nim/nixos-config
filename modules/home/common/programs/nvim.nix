{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = [
    inputs.nixCats.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
