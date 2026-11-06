# pkgs supplies locked packages; builder is nix2container's buildImage API.
{ pkgs, builder }:
let
  packages = import ./packages.nix { inherit pkgs; };
  # The image and host account must use the same IDs.
  uid = 1004;
  gid = 1004;
  fonts = [
    pkgs.dejavu_fonts
    pkgs.noto-fonts-color-emoji
  ];
  environment = {
    HOME = "/state/runtime/pi-home";
    PI_CODING_AGENT_DIR = "/state/runtime/pi-home/.pi/agent";
    XDG_CACHE_HOME = "/tmp/open-design-cache";
    OD_DATA_DIR = "/state";
    OD_BIND_HOST = "0.0.0.0";
    OD_PORT = "7456";
    OD_WEB_PORT = "7456";
    OD_ALLOWED_ORIGINS = "https://design.pieczarkowo.me";
    OD_DISABLE_API_AUTH = "1";
    # OD Next rejects visual-check instructions; use its supported rollback route.
    OD_NEXT_STRATEGY_ROLLOUT = "off";
    OD_PROMPT_CORE = "slim";
    OD_BROWSER_EXECUTABLE_PATH = "/bin/chromium-headless";
    AGENT_BROWSER_EXECUTABLE_PATH = "/bin/chromium";
    NODE_OPTIONS = "--max-old-space-size=512";
    NODE_ENV = "production";
    PATH = "/bin";
    SHELL = "/bin/bash";
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    FONTCONFIG_FILE = toString (pkgs.makeFontsConf { fontDirectories = fonts; });
    LANG = "C.UTF-8";
    # Leave time for the launcher's bounded cleanup before upstream SIGKILL.
    PI_ABORT_GRACE_MS = "3000";
  };
  tools = pkgs.buildEnv {
    name = "open-design-tools";
    paths = [
      packages.nodejs
      packages.runtime
      pkgs.chromium
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.git
      # PDF previews call pdftotext.
      pkgs.poppler-utils
      pkgs.curl
      pkgs.ripgrep
      pkgs.python3
      pkgs.tini
      # OpenDesign uses ps to identify and stop agent processes.
      pkgs.procps
      pkgs.fontconfig
    ];
    pathsToLink = [ "/bin" ];
  };
  root = pkgs.runCommand "open-design-root" { } ''
    mkdir -p "$out/bin" "$out/etc/open-design" "$out/tmp" "$out/state" "$out/app"
    cp -as ${tools}/bin/. "$out/bin/"
    chmod u+w "$out/bin"
    cp -as ${packages.app}/. "$out/app/"
    cp ${./pi-launcher.mjs} "$out/etc/open-design/pi-launcher.mjs"
    cp ${./pi-policy.md} "$out/etc/open-design/pi-policy.md"
    cp ${./entrypoint.sh} "$out/bin/open-design-entrypoint"
    cp ${./chromium-headless} "$out/bin/chromium-headless"
    cp ${./doctor.mjs} "$out/etc/open-design/doctor.mjs"
    cp ${./configure.mjs} "$out/etc/open-design/configure.mjs"
    cat > "$out/bin/pi" <<'SH'
    #!${pkgs.bash}/bin/bash
    exec ${packages.nodejs}/bin/node /etc/open-design/pi-launcher.mjs "$@"
    SH
    cat > "$out/bin/pi-real" <<'SH'
    #!${pkgs.bash}/bin/bash
    exec ${packages.nodejs}/bin/node ${packages.runtime}/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js "$@"
    SH
    chmod +x "$out/bin/"{pi,pi-real,chromium-headless,open-design-entrypoint}
    printf 'root:x:0:0:root:/root:/bin/bash\nopen-design:x:${toString uid}:${toString gid}:OpenDesign:/state/runtime/pi-home:/bin/bash\n' > "$out/etc/passwd"
    printf 'root:x:0:\nopen-design:x:${toString gid}:\n' > "$out/etc/group"
    cat > "$out/etc/open-design/versions.json" <<'JSON'
    ${builtins.toJSON {
      openDesign = packages.app.version;
      openDesignPackageVersion = "0.25.1";
      pi = "1.5.0";
      agentBrowser = "0.41.2";
      node = packages.nodejs.version;
      chromium = pkgs.chromium.version;
      fonts = map (font: { inherit (font) pname version; }) fonts;
    }}
    JSON
  '';
  image = builder.buildImage {
    name = "localhost/open-design";
    copyToRoot = root;
    maxLayers = 80;
    config = {
      User = "${toString uid}:${toString gid}";
      WorkingDir = "/app";
      Entrypoint = [
        "${pkgs.tini}/bin/tini"
        "-g"
        "--"
        "/bin/open-design-entrypoint"
      ];
      Env = pkgs.lib.mapAttrsToList (name: value: "${name}=${value}") environment;
      ExposedPorts."7456/tcp" = { };
      Labels."org.opencontainers.image.revision" = "77b8eb889cf8a27a50d3325029d1b3bee5da0910";
    };
  };
in
{
  inherit
    image
    environment
    uid
    gid
    ;
}
