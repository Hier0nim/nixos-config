{
  nixpkgs,
  inputs,
  outputs,
  self,
  system,
  modules,
  specialArgs ? { },
}:
let
  hostLib = nixpkgs.lib.extend (self: _super: { custom = import ./. { lib = self; }; });
in
nixpkgs.lib.nixosSystem {
  inherit system modules;
  specialArgs = {
    inherit
      inputs
      outputs
      self
      ;
    lib = hostLib;
  }
  // specialArgs;
}
