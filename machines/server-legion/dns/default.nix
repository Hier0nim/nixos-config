# Evaluate the service registry through Terranix; keep execution and state in ordinary OpenTofu.
{
  pkgs,
  ingress,
  clan,
  terranix,
}:
let
  directTarget = "yze78b4.glddns.com";
  mkRecords = import ./records.nix;
  tools = pkgs.opentofu.withPlugins (plugins: [ plugins.cloudflare_cloudflare ]);
  writeConfig =
    records:
    terranix.lib.terranixConfiguration {
      inherit pkgs;
      modules = [ ./configuration.nix ];
      extraArgs = {
        inherit records;
        inherit (ingress) domain;
        providerVersion = pkgs.terraform-providers.cloudflare_cloudflare.version;
      };
    };
  configuration = writeConfig (mkRecords {
    inherit ingress directTarget;
  });
  command = pkgs.writeShellApplication {
    name = "legion-dns";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.nix
    ];
    text = ''
      # Run from the repository root; keep credentials and state outside the store.
      set +x
      umask 077
      if [[ $# == 0 || "$1" == "--help" || "$1" == "-help" || "$1" == "version" ]]; then
        exec ${tools}/bin/tofu "$@"
      fi
      repo=$(pwd -P)
      [[ -f "$repo/vars/per-machine/server-legion/cloudflare-dns/api-token/secret" ]] || {
        echo 'Run legion-dns from the nixos-config repository root.' >&2; exit 1;
      }
      state=$(realpath -m "''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-config/legion-dns/operator")
      case "$state/" in "$repo/"*|/nix/store/*)
        echo 'DNS state must be outside the repository and Nix store.' >&2; exit 1;;
      esac
      [[ ! -e "$state" || -O "$state" ]] || exit 1
      install -d -m 0700 "$state"
      cd "$state"
      exec 9>.operator.lock
      flock -n 9 || { echo 'Another legion-dns command is running.' >&2; exit 1; }
      [[ ! -L terraform.tfstate ]] || exit 1
      if [[ -e terraform.tfstate ]]; then
        [[ -O terraform.tfstate && "$(stat -c %a terraform.tfstate)" == 600 ]] || exit 1
      fi
      shopt -s nullglob
      for file in *.tf *.tf.json *.tofu *.tofu.json *.tfvars *.tfvars.json; do
        [[ "$file" == main.tf.json ]] || {
          echo 'Unexpected Terraform configuration or variables in the DNS workspace.' >&2; exit 1;
        }
      done
      ln -sfn ${configuration} main.tf.json
      # Ignore inherited logging, CLI overrides and unrelated Cloudflare credentials.
      for variable in ''${!TF_@} ''${!TOFU_@} ''${!CLOUDFLARE_@}; do unset "$variable"; done
      export TF_WORKSPACE=default TF_IN_AUTOMATION=1 CHECKPOINT_DISABLE=1
      CLOUDFLARE_API_TOKEN=$(${clan}/bin/clan vars get server-legion cloudflare-dns/api-token --flake "$repo")
      [[ -n "$CLOUDFLARE_API_TOKEN" && "$CLOUDFLARE_API_TOKEN" != *[[:space:]]* ]] || exit 1
      export CLOUDFLARE_API_TOKEN
      exec ${tools}/bin/tofu "$@"
    '';
  };
in
{
  inherit configuration tools command;
  check = import ./tests.nix {
    inherit
      pkgs
      directTarget
      mkRecords
      configuration
      tools
      ;
  };
}
