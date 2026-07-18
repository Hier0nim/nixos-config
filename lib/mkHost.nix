{
  nixpkgs,
  inputs,
  outputs,
  self,
  system,
  modules,
  specialArgs ? { },
  customLib,
}:
nixpkgs.lib.nixosSystem {
  inherit system modules;
  specialArgs = {
    inherit
      customLib
      inputs
      outputs
      self
      ;
  }
  // specialArgs;
}
