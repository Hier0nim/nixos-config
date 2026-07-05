_: {

  # Pin llama-cpp to a specific nixpkgs revision to avoid rebuilding with CUDA on every nixpkgs update.
  # To update: change the rev below, then run `nix flake update` (the hash in flake.lock won't change).
  llama-cpp-pin =
    final: _prev:
    let
      pinnedPkgs =
        import
          (final.fetchFromGitHub {
            owner = "NixOS";
            repo = "nixpkgs";
            # Current unstable — change this rev when you want a new llama-cpp version
            rev = "ca77296380960cd497a765102eeb1356eb80fed0";
            hash = "sha256-PgLSZDBEWUHpfTRfFyklmiiLBE1i1aGCtz4eRA3POao=";
          })
          {
            inherit (final.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          };
    in
    {
      inherit (pinnedPkgs) llama-cpp;
    };
}
