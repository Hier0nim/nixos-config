{ inputs, ... }:
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };

    overlays = [
    ];
  };
}
