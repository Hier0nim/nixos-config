# Personal Home Manager profile, imported explicitly by the consuming machine.
# Clan's users service provisions the account independently.
{ self, ... }:
{
  imports = [
    self.inputs.home-manager.nixosModules.home-manager
    ./ssh.nix
    ./copyparty.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit (self) inputs; };
    users.hieronim = import ./home.nix;
  };
}
