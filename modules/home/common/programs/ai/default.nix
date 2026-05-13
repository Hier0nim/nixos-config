{ inputs, ... }:
{
  imports = [
    inputs.pi-config.homeManagerModules.default
    ./coding-agents.nix
    ./llm-bench.nix
  ];
}
