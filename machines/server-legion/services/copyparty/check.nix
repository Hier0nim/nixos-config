{ pkgs, config }:
let
  inherit (pkgs) lib;
  party = config.services.copyparty;
  service = config.services.homelabIngress.services.pliki;
  testConfig = pkgs.writeText "copyparty-test.json" (
    builtins.toJSON {
      preStart = config.systemd.services.copyparty.preStart;
      caddyPreStart = config.systemd.services.caddy.preStart;
      passwords = lib.mapAttrs (_: account: account.passwordFile) party.accounts;
      route = config.services.caddy.virtualHosts."pliki.pieczarkowo.me".extraConfig;
    }
  );
in
assert service.auth == "proxy" && service.group == "household";
assert !service.integrationApiBypass;
assert
  builtins.attrNames party.accounts == [
    "admin"
    "hieronim"
    "sarcia"
  ];
assert
  party.accounts.sarcia.passwordFile
  == config.clan.core.vars.generators.copyparty.files.sarka-password.path;
assert !(party.settings.usernames or false);
assert party.settings.i == "127.0.0.1" && party.settings.p == 3923 && party.settings.rproxy == 1;
assert (party.settings.shr or "") == "";
assert party.settings.xff-src == "127.0.0.1/32";
assert party.settings.idp-h-key == "@@COPYPARTY_IDP_KEY@@";
assert party.settings.idp-cookie == 0 && party.settings.idp-store == 0;
assert !(party.volumes ? "/nas/sarka") && !(party.accounts ? sarka);
assert party.volumes."/nas/sarcia".path == "/data/nas/sarcia";
assert lib.elem "d /data/nas/sarcia 2770 root nas - -" config.systemd.tmpfiles.rules;
assert
  !(lib.hasInfix "/data/nas/sarka" (
    builtins.toJSON {
      inherit (config.systemd.tmpfiles) rules settings;
    }
  ));
assert
  party.volumes."/nas/sarcia".access.rwmd == [
    "admin"
    "sarcia"
  ];
assert
  party.volumes."/nas/hieronim".access.rwmd == [
    "admin"
    "hieronim"
  ];
assert
  party.volumes."/nas/shared".access.rwmd == [
    "admin"
    "hieronim"
    "sarcia"
  ];
assert lib.elem "copyparty-local-guard.service" config.systemd.services.caddy.requires;
assert config.systemd.services.caddy.serviceConfig.RuntimeDirectoryMode == "0700";
assert lib.hasInfix "/run/caddy/copyparty-idp.caddy" config.systemd.services.caddy.preStart;
assert lib.elem "copyparty-local-guard.service" config.systemd.services.copyparty.requires;
assert lib.hasInfix "iptables -D OUTPUT" config.systemd.services.copyparty-local-guard.preStop;
assert !(lib.hasInfix "actual-local" config.systemd.services.copyparty-local-guard.preStop);
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
