# Machine-local power policy, split by responsibility.
{
  imports = [
    ./asus.nix
    ./radio-power.nix
    ./gpu.nix
    ./sleep.nix
  ];
}
