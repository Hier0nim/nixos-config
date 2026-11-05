{ pkgs, config }:
let
  python = pkgs.python3.withPackages (ps: [
    ps.pyyaml
    ps.bcrypt
  ]);
  fixtures = pkgs.writeText "monitoring-settings.json" (
    builtins.toJSON {
      ntfy = config.services.ntfy-sh.settings;
      gatus = config.services.gatus.settings;
      summary = config.services.caddy.virtualHosts."http://127.0.0.1:8086".extraConfig;
    }
  );
in
pkgs.runCommand "legion-monitoring"
  {
    nativeBuildInputs = [
      python
      config.services.ntfy-sh.package
      config.services.gatus.package
      config.services.caddy.package
    ];
    FIXTURES = fixtures;
    NTFY_GENERATOR = ../ntfy/generate-secrets.py;
  }
  ''
    export HOME="$TMPDIR"
    export PYTHONDONTWRITEBYTECODE=1
    python3 ${./test.py}
    touch "$out"
  ''
