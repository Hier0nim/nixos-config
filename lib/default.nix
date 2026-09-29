{ self, ... }:
{
  # use path relative to the root of the project
  relativeToRoot = path: "${self.outPath}/${path}";
  mkHost = import ./mkHost.nix;
}
