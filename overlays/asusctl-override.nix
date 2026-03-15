/*
  Optional asusctl override template.

  Usage: enable in `modules/nixos/core/nix/nix.nix`:
    overlays = [
      (import ../../../../overlays/asusctl-override.nix)
    ];

  Fill in a real hash before enabling.

  final: prev: {
    asusctl = prev.asusctl.overrideAttrs (old: rec {
      version = "6.3.4";

      src = prev.fetchFromGitLab {
        owner = "asus-linux";
        repo = "asusctl";
        tag = version;

        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };
    });
  }
*/

final: prev: { }
