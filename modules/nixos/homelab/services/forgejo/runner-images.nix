{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.services.forgejo.actions;
  nixSeedEpoch = "2";
  nixCleanupHook = pkgs.writeShellScriptBin "forgejo-nix-cleanup" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/rm -rf -- /homeless-shelter
  '';
  nixSeed = pkgs.buildEnv {
    name = "forgejo-runner-nix-seed";
    paths = with pkgs; [
      bashInteractive
      cacert
      coreutils
      findutils
      gitMinimal
      gnugrep
      gnused
      gnutar
      gzip
      nix
      which
      xz
      nixCleanupHook
    ];
    pathsToLink = [
      "/bin"
      "/etc"
    ];
  };
  seedExtraCommands = ''
    mkdir -p etc/nix root tmp workspace usr/local/bin nix/store nix/var/nix
    rm -rf homeless-shelter
    ln -s ${nixSeed}/bin/nix usr/local/bin/nix
    printf '%s\n' ${nixSeedEpoch} >nix/.forgejo-nix-seed-epoch
    chmod 01777 tmp
    chmod 1777 nix/store nix/var/nix
    cat >etc/nix/nix.conf <<'EOF'
    experimental-features = nix-command flakes
    substituters = https://cache.nixos.org/
    trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
    min-free = ${toString (cfg.nixCacheMinFreeMiB * 1024 * 1024)}
    max-free = ${toString (cfg.nixCacheMaxFreeMiB * 1024 * 1024)}
    post-build-hook = /bin/forgejo-nix-cleanup
    sandbox = false
    build-users-group =
    EOF
  '';
  imageConfig = {
    Cmd = [ "/bin/bash" ];
    Env = [
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt"
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ];
    WorkingDir = "/workspace";
  };
  nodeBaseImage = pkgs.dockerTools.pullImage {
    imageName = "node";
    imageDigest = "sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0";
    hash = "sha256-ItPyOSuJqotRlavzY2w7pBHrmGLqv8FzNsWUHNGWNrM=";
    finalImageName = "node";
    finalImageTag = "20-bookworm-slim";
  };
  runnerNixImage = pkgs.dockerTools.buildLayeredImageWithNixDb {
    name = "forgejo-runner-nix";
    tag = pkgs.nix.version;
    fromImage = nodeBaseImage;
    contents = nixSeed;
    extraCommands = ''
      ${seedExtraCommands}
      printf '%s\n' 'root:x:0:0:root:/root:/bin/sh' >etc/passwd
    '';
    config = imageConfig;
  };
in
{
  config.homelab.services.forgejo.actions.images = lib.mkDefault {
    nix = {
      archive = runnerNixImage;
      reference = "forgejo-runner-nix:${pkgs.nix.version}";
      inherit nixSeedEpoch;
    };
  };
}
