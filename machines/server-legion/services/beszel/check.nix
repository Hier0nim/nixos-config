{ pkgs, config }:
pkgs.runCommand "legion-beszel-contracts"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.openssl
    ];
    BESZEL_PACKAGE = config.services.beszel.hub.package;
    BESZEL_PROVISIONER = ./beszel-oidc.py;
  }
  ''
    python3 ${./test.py}
    touch "$out"
  ''
