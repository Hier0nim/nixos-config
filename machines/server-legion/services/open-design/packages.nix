# pkgs is the fleet's locked Nixpkgs set.
{ pkgs }:
let
  inherit (pkgs) lib;
  lock = builtins.fromJSON (builtins.readFile ./image-lock.json);
  nodejs = pkgs.nodejs_24;
  pnpm = pkgs.pnpm_10;
  # Node 24.19 added ObjectWrap cleanup hooks to the addon header without the
  # runtime registry that makes their removal safe, so an addon built from those
  # headers aborts in RemoveEnvironmentCleanupHook when V8 frees it. Build the
  # native addons from headers without those calls until Node fixes the backport.
  nodeHeaders = pkgs.runCommand "node-headers-${nodejs.version}-no-objectwrap-cleanup-hook" { } ''
    mkdir -p "$out/include"
    cp -rL ${nodejs}/include/node "$out/include/node"
    chmod -R u+w "$out/include/node"
    substituteInPlace "$out/include/node/node_object_wrap.h" \
      --replace-fail "    AddCleanupHook();" "" \
      --replace-fail "    RemoveCleanupHook();" ""
  '';
  source = pkgs.fetchzip {
    url = "https://github.com/nexu-io/open-design/archive/${lock.openDesign.commit}.tar.gz";
    hash = lock.openDesign.sourceHash;
  };
  # Other workspaces include desktop-only dependencies.
  workspaces = [
    "@open-design/daemon..."
    "@open-design/web..."
  ];
  app = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "open-design";
    version = lock.openDesign.release;
    src = source;
    pnpmDeps = pnpm.fetchDeps {
      inherit (finalAttrs) pname version src;
      pnpmWorkspaces = workspaces;
      fetcherVersion = 4;
      hash = lock.openDesign.pnpmHash;
    };
    pnpmWorkspaces = workspaces;
    nativeBuildInputs = [
      nodejs
      pnpm
      pkgs.pnpmConfigHook
      pkgs.python3
      pkgs.pkg-config
      pkgs.autoPatchelfHook
    ];
    buildInputs = [
      pkgs.libsecret
      pkgs.stdenv.cc.cc.lib
    ];
    env = {
      CI = "true";
      npm_config_manage_package_manager_versions = "false";
      NEXT_TELEMETRY_DISABLED = "1";
      ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      npm_config_nodedir = "${nodeHeaders}";
      npm_config_build_from_source = "true";
      OPEN_DESIGN_POSTINSTALL_TARGETS = ''["apps/daemon","packages/components","packages/host"]'';
    };
    postPatch = ''
      # Pi 1.5 finishes automatic recovery at agent_settled, not agent_end.
      substituteInPlace apps/daemon/src/agent-protocol/pi-rpc/events.ts \
        --replace-fail "if (raw.type === 'agent_end')" "if (raw.type === 'agent_settled')"
    '';
    buildPhase = ''
      runHook preBuild
      node scripts/postinstall.mjs build
      pnpm --filter @open-design/web build
      # Legacy pnpm deploy resolves dependencies again instead of using the lock.
      pnpm --config.inject-workspace-packages=true --filter @open-design/daemon deploy --prod --offline --ignore-scripts "$TMPDIR/deployed"
      # Build native addons without npm's prepare hooks or prebuilt downloads.
      for addon in better-sqlite3 node-pty; do
        manifest=$(node -p 'require.resolve(process.argv[1] + "/package.json", {paths: [process.argv[2]]})' "$addon" "$TMPDIR/deployed")
        (cd "$(dirname "$manifest")"; node ${nodejs}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --release)
      done
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/apps/daemon" "$out/apps/web"
      cp -a "$TMPDIR/deployed/." "$out/apps/daemon/"
      cp -a apps/web/out "$out/apps/web/"
      for dir in skills design-systems design-templates craft prompt-templates data assets plugins/_official; do
        mkdir -p "$out/$(dirname "$dir")"
        cp -a "$dir" "$out/$dir"
      done
      cp package.json "$out/"
      cp ${./agent-browser/SKILL.md} "$out/skills/agent-browser/SKILL.md"
      node -e 'const {createRequire}=require("module"); const r=createRequire(process.argv[1]); new (r("better-sqlite3"))(":memory:").close()' "$out/apps/daemon/package.json"
      for dir in skills design-systems design-templates plugins/_official; do
        test -n "$(find "$out/$dir" -type f -print -quit)"
      done
      test -s "$out/apps/web/out/index.html"
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      node ${./preflight.mjs} "$out" ${runtime} ${./pi-policy.md}
    '';
    meta.license = lib.licenses.asl20;
  });
  runtime = pkgs.buildNpmPackage {
    pname = "open-design-agent-runtime";
    version = "1.0.0";
    src = ./runtime;
    inherit nodejs;
    npmDepsHash = lock.runtime.npmHash;
    npmFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.libxcb
    ];
    installPhase = ''
      mkdir -p "$out/lib" "$out/bin"
      cp -a node_modules "$out/lib/"
      binary="$out/lib/node_modules/agent-browser/bin/agent-browser-linux-x64"
      echo '${lock.runtime.agentBrowserBinarySha256}  '"$binary" | sha256sum --check
      chmod +x "$binary"
      ln -s "$binary" "$out/bin/agent-browser"
      ln -sfn ../agent-browser/bin/agent-browser-linux-x64 "$out/lib/node_modules/.bin/agent-browser"
      # Drop binaries for other platforms.
      find "$out/lib/node_modules/agent-browser/bin" -type f ! -name agent-browser-linux-x64 -delete
    '';
    meta.license = lib.licenses.mit;
  };
in
{
  inherit app runtime nodejs;
}
