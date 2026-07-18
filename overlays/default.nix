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

  # Fix minion on NixOS: use PR branch with JavaFX fix, then add GTK schema paths
  # required by JavaFX/GTK file chooser (`org.gtk.Settings.FileChooser`).
  minion =
    final: _prev:
    let
      prSrc = final.fetchFromGitHub {
        owner = "shr3yas-k";
        repo = "nixpkgs";
        rev = "a7f249c0d67ed58d30a3c29fc6140d29a8e76c03";
        hash = "sha256-tcT5l1Yo+op5rYIXHQmev/Qgr2rqnzH71eqrNx+kx78=";
      };
      prPkgs = import prSrc {
        inherit (final.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
      gtkSchemaDirs = final.lib.concatStringsSep ":" [
        "${final.gsettings-desktop-schemas}/share/gsettings-schemas/${final.gsettings-desktop-schemas.name}"
        "${final.gtk3}/share/gsettings-schemas/${final.gtk3.name}"
      ];
    in
    {
      minion = prPkgs.minion.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [
          final.gsettings-desktop-schemas
          final.gtk3
          final.glib
        ];

        # The upstream PR creates $out/bin/minion during installPhase. Wrap that
        # wrapper once more with the exact XDG_DATA_DIRS layout that works in
        # `nix shell`: .../share/gsettings-schemas/<package-name>.
        postInstall = (old.postInstall or "") + ''
          wrapProgram $out/bin/minion \
            --prefix XDG_DATA_DIRS : "${gtkSchemaDirs}"
        '';
      });
    };
}
