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
  modules = [
    { nixpkgs.hostPlatform = system; }
  ]
  ++ modules;
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
