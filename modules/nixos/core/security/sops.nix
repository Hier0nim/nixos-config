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
    # Use one dedicated AGE identity shared by NixOS and Home Manager.
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

  # Allow group-based access so Home Manager can read the shared key.
  users.groups.sops = { };

  systemd.tmpfiles.rules = [
    # Maintain permissions for the shared key and its directory.
    "d /var/lib/sops-nix 0750 root sops -"
    "z /var/lib/sops-nix/key.txt 0640 root sops -"
  ];
}
