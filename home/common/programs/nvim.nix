{
  inputs,
  ...
}:
{
  home.packages = [
    inputs.nixCats.packages.x86_64-linux.default
  ];
}
