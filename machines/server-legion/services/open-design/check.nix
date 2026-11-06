# pkgs supplies test tools; config is Legion with OpenDesign explicitly enabled.
{ pkgs, config }:
let
  inherit (pkgs) lib;
  container = config.virtualisation.oci-containers.containers.open-design;
  ingress = config.services.homelabIngress.services.design;
  snapshot = config.systemd.services.homelab-app-state-snapshot.script;
  service = config.systemd.services.docker-open-design;
in
assert lib.all (entry: entry.assertion) config.assertions;
assert ingress.auth == "proxy";
assert ingress.group == "household";
assert !ingress.integrationApiBypass;
assert container.ports == [ "127.0.0.1:7456:7456" ];
assert container.volumes == [ "/var/lib/open-design:/state" ];
assert container.user == "1004:1004";
assert container.pull == "never";
assert container.networks == [ "bridge" ];
assert lib.elem "open-design-local-guard.service" service.requires;
assert !container.privileged;
assert container.environment.OD_DISABLE_API_AUTH == "1";
assert container.environment.OD_NEXT_STRATEGY_ROLLOUT == "off";
assert container.environment.OD_PROMPT_CORE == "slim";
assert !(container.environment ? OD_BROWSER_CDP_URL);
assert lib.all (flag: lib.elem flag container.extraOptions) [
  "--read-only"
  "--cap-drop=ALL"
  "--security-opt=no-new-privileges:true"
];
assert
  !lib.any (
    flag: lib.hasInfix "--network=host" flag || lib.hasInfix "--privileged" flag
  ) container.extraOptions;
assert lib.elem "d /var/lib/open-design 0700 open-design open-design - -"
  config.systemd.tmpfiles.rules;
assert config.clan.core.state.open-design.folders == [ "/var/backup/homelab/open-design" ];
assert lib.hasInfix "docker-open-design.service" snapshot;
assert lib.length service.serviceConfig.ExecStartPost > 0;
assert
  lib.length (
    lib.filter (entry: lib.hasInfix "copy-to-docker-daemon" entry) service.serviceConfig.ExecStartPre
  ) == 1;
pkgs.runCommand "legion-open-design-check"
  {
    nativeBuildInputs = [
      pkgs.nodejs_24
      pkgs.shellcheck
    ];
  }
  ''
    shellcheck ${./entrypoint.sh} ${./chromium-headless}
    shellcheck --shell=bash ${./smoke-test.sh}
    node --check ${./pi-launcher.mjs}
    node --check ${./doctor.mjs}
    node --check ${./configure.mjs}
    node --check ${./preflight.mjs}
    node --test ${./.}/test-launcher.mjs
    touch "$out"
  ''
