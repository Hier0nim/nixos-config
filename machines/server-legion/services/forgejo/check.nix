{ pkgs, config }:
let
  forgejo = config.services.forgejo;
in
pkgs.runCommand "legion-forgejo-contracts"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.openssl
      pkgs.git
    ];
    FORGEJO_PACKAGE = forgejo.package;
    FORGEJO_DATA = forgejo.package.data;
    FORGEJO_PRESTART = pkgs.writeText "forgejo-prestart" config.systemd.services.forgejo.preStart;
  }
  ''
    python3 ${./test.py}
    touch "$out"
  ''
