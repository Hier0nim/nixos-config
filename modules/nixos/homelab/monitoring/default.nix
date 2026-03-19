{ lib, ... }:
{
  imports = lib.flatten [
    ./metrics.nix
    ./logs.nix
    ./grafana.nix
    ./cockpit.nix
  ];
}
