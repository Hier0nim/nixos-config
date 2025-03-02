{
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      shellHook = ''
        ${config.pre-commit.installationScript}
      '';

      DIRENV_LOG_FORMAT = "";

      packages = with pkgs; [
        git
        nil
        statix
        nix
        home-manager
        nh
        git
        deadnix
      ];
    };

    formatter = pkgs.nixfmt-rfc-style;
  };
}
