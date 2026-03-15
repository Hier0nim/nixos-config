{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # Encrypted secrets live in `secrets/common` and `secrets/<host>`.
  # SOPS config is stored at `secrets/.sops.yaml`.
  # Encrypt files with: sops -e -i secrets/common/<name>.yaml
  sops = {
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # Default location for shared secrets (create the encrypted file when ready).
    defaultSopsFile = lib.mkDefault (config.custom.repoPath + "/secrets/common/secrets.yaml");

    # Example secret declaration (uncomment when adding your first secret).
    # secrets.example = {
    #   sopsFile = ../../../../secrets/common/example.yaml;
    # };
    #
    # Host-specific example:
    # secrets.host_example = {
    #   sopsFile = ../../../../secrets/zephyrus-g14/example.yaml;
    # };
  };

  # Host key setup (run once per host):
  #   sudo mkdir -p /var/lib/sops-nix
  #   sudo age-keygen -o /var/lib/sops-nix/key.txt
  #   age-keygen -y /var/lib/sops-nix/key.txt
  # Add the public key output to `secrets/.sops.yaml` for this host.
}
