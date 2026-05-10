# Shell for bootstrapping flake-enabled nix and other tooling
let
  lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);

  lockedInput =
    name:
    let
      nodeName = lockFile.nodes.${lockFile.root}.inputs.${name};
    in
    lockFile.nodes.${nodeName}.locked;

  nixpkgsFromLock =
    name:
    let
      lock = lockedInput name;
    in
    fetchTarball (
      {
        sha256 = lock.narHash;
      }
      // (
        if lock ? url then
          { inherit (lock) url; }
        else
          { url = "https://github.com/${lock.owner}/${lock.repo}/archive/${lock.rev}.tar.gz"; }
      )
    );
in
{
  system ? builtins.currentSystem,
  pkgs ?
    # If pkgs is not defined, instantiate nixpkgs from locked commit
    let
      nixpkgs = nixpkgsFromLock "nixpkgs";
    in
    import nixpkgs {
      inherit system;
      overlays = [ ];
    },
  pkgsUnstable ?
    # Optional package set for pulling selected tools from unstable when pkgs is stable.
    let
      nixpkgs = nixpkgsFromLock "nixpkgs";
    in
    import nixpkgs {
      inherit system;
      overlays = [ ];
    },
  unstablePackages ? [ ],
  checks,
  ...
}:
let
  selectedUnstablePackages =
    if builtins.isFunction unstablePackages then unstablePackages pkgsUnstable else unstablePackages;

  sopsBootstrap = pkgs.writeShellScriptBin "sops-bootstrap-key" ''
    set -euo pipefail

    key_dir=/var/lib/sops-nix
    key_file="$key_dir/key.txt"
    src_key="''${1-}"

    if [ -z "$src_key" ]; then
      echo "Usage: sops-bootstrap-key /path/to/key.txt" >&2
      exit 2
    fi

    if [ ! -f "$src_key" ]; then
      echo "Source key not found: $src_key" >&2
      exit 1
    fi

    if ! sudo test -d "$key_dir"; then
      sudo install -d -m 0750 -o root -g sops "$key_dir"
    fi

    if ! sudo test -f "$key_file"; then
      sudo install -m 0640 -o root -g sops "$src_key" "$key_file"
    fi

    sudo age-keygen -y "$key_file"
  '';
in
{
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
    SOPS_CONFIG = "./secrets/.sops.yaml";
    SOPS_AGE_KEY_FILE = "/var/lib/sops-nix/key.txt";

    inherit (checks.pre-commit-check) shellHook;
    buildInputs = checks.pre-commit-check.enabledPackages;

    nativeBuildInputs =
      builtins.attrValues {
        inherit (pkgs)

          nix
          home-manager
          nh
          git
          just
          pre-commit
          deadnix
          sops
          age
          ssh-to-age
          files-to-prompt
          nixfmt-tree
          ;
      }
      ++ [
        pkgsUnstable.codex
        sopsBootstrap
      ]
      ++ selectedUnstablePackages;
  };
}
