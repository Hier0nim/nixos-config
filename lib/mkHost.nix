{ lib }:
{
  nixpkgs,
  inputs,
  outputs,
  self,
  system,
  modules,
  specialArgs ? { },
}:
nixpkgs.lib.nixosSystem {
  inherit system modules;
  specialArgs = {
    inherit
      inputs
      outputs
      lib
      self
      ;
  }
  // specialArgs;
}
