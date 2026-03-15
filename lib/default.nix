{ lib, ... }:
{
  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;
  mkHost = import ./mkHost.nix { inherit lib; };
}
