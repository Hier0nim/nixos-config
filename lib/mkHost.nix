{ lib }:
{
  nixpkgs,
  inputs,
  outputs,
  system,
  modules,
  specialArgs ? { },
}:
nixpkgs.lib.nixosSystem {
  inherit system modules;
  specialArgs = {
    inherit inputs outputs lib;
  }
  // specialArgs;
}
