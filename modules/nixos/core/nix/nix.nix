{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  overlaysDir = lib.custom.relativeToRoot "overlays";
  overlayFiles =
    if builtins.pathExists overlaysDir then
      map (name: overlaysDir + "/${name}") (
        lib.filter (name: lib.strings.hasSuffix ".nix" name) (
          builtins.attrNames (builtins.readDir overlaysDir)
        )
      )
    else
      [ ];
in
{
  nix = {
    # This will add each flake input as a registry
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # See https://jackson.dev/post/nix-reasonable-defaults/
      connect-timeout = 5;
      log-lines = 25;
      min-free = 128000000; # 128MB
      max-free = 1000000000; # 1GB

      trusted-users = [ "@wheel" ];

      # Deduplicate and optimize nix store
      auto-optimise-store = true;
      warn-dirty = false;

      allow-import-from-derivation = true;

      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };

    overlays = map import overlayFiles;
  };

  # We need git for flakes
  environment.systemPackages = [ pkgs.git ];

  # Provide better build output and will also handle garbage collection
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 20d --keep 20";
    flake = toString config.custom.repoPath;
  };
}
