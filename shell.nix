# Shell for bootstrapping flake-enabled nix and other tooling
{
  pkgs ?
    # If pkgs is not defined, instantiate nixpkgs from locked commit
    let
      lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
      nixpkgs = fetchTarball {
        url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
        sha256 = lock.narHash;
      };
    in
    import nixpkgs { overlays = [ ]; },
  checks,
  ...
}:
let
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
        sopsBootstrap
      ];
  };
}
