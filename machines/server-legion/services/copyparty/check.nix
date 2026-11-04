{ pkgs, config }:
let
  inherit (pkgs) lib;
  party = config.services.copyparty;
  testConfig = pkgs.writeText "copyparty-test.json" (
    builtins.toJSON {
      preStart = config.systemd.services.copyparty.preStart;
      caddyPreStart = config.systemd.services.caddy.preStart;
      passwords = lib.mapAttrs (_: account: account.passwordFile) party.accounts;
      route = config.services.caddy.virtualHosts."pliki.pieczarkowo.me".extraConfig;
    }
  );
in
pkgs.runCommand "legion-copyparty-contracts"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.caddy
      pkgs.openssl
      pkgs.bash
    ];
    COPYPARTY_PACKAGE = party.package;
    COPYPARTY_TEST_CONFIG = testConfig;
  }
  ''
    python3 ${./test.py}
    touch "$out"
  ''
