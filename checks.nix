{
  inputs,
  pkgs,
  system,
  nixosConfigurations,
  ...
}:
let
  lib = inputs.nixpkgs.lib;
  # Only check hosts matching the current system
  hostChecks = lib.mapAttrs' (
    name: cfg: lib.nameValuePair "nixos-${name}" cfg.config.system.build.toplevel
  ) (lib.filterAttrs (_: cfg: cfg.config.nixpkgs.hostPlatform.system == system) nixosConfigurations);
  runnerConfig = nixosConfigurations.server-legion.config.microvm.vms.forgejo-runner.config.config;
  runnerActions = nixosConfigurations.server-legion.config.homelab.services.forgejo.actions;
  runnerImages = map (
    imageName: runnerActions.images.${imageName}
  ) runnerActions.runners.global.runner.imageNames;
  runnerLabels = runnerActions.runners.global.runner.labels;
  cleanupTestHook = pkgs.writeShellScript "forgejo-nix-cleanup-regression-hook" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/rm -rf -- /tmp/forgejo-nix-cleanup-regression/homeless-shelter
  '';
  runnerSeedEpoch = runnerActions.runners.global.runner.nixSeedEpoch;
  recoveryScript =
    nixosConfigurations.server-legion.config.systemd.services.forgejo-runner-docker-recovery-global.serviceConfig.ExecStart;
  runnerService = runnerConfig.systemd.services."gitea-runner-global";
  runnerContainerOptions =
    runnerConfig.services.gitea-actions-runner.instances.global.settings.container.options;
  runnerValidVolumes =
    runnerConfig.services.gitea-actions-runner.instances.global.settings.container.valid_volumes;
  runnerContainerPrivileged =
    runnerConfig.services.gitea-actions-runner.instances.global.settings.container.privileged;
  runnerContainerDockerHost =
    runnerConfig.services.gitea-actions-runner.instances.global.settings.container.docker_host;
  runnerEnvs = runnerConfig.services.gitea-actions-runner.instances.global.settings.runner.envs;
  runnerHttpsProxy = runnerEnvs.HTTPS_PROXY or "";
  runnerNoProxy = runnerEnvs.NO_PROXY or "";
  runnerHttpProxyLower = runnerEnvs.http_proxy or "";
  runnerHttpsProxyLower = runnerEnvs.https_proxy or "";
  runnerNoProxyLower = runnerEnvs.no_proxy or "";
  runnerNixVolumeScript =
    runnerConfig.systemd.services.forgejo-runner-nix-volume-global.serviceConfig.ExecStart;
  runnerCacheResetScript =
    nixosConfigurations.server-legion.config.systemd.services.forgejo-runner-nix-cache-reset-global.serviceConfig.ExecStart;
  runnerCacheMigrationScript =
    nixosConfigurations.server-legion.config.systemd.services.forgejo-runner-nix-cache-migrate-global.serviceConfig.ExecStart;
  runnerDockerProxies = runnerConfig.virtualisation.docker.daemon.settings.proxies;
  runnerDockerObserver = runnerConfig.systemd.services.forgejo-runner-docker-observer-global;
  runnerDockerObserverScript = runnerDockerObserver.serviceConfig.ExecStart;
  runnerDockerObserverRestart = runnerDockerObserver.serviceConfig.Restart;
  runnerDockerObserverRestartSec = runnerDockerObserver.serviceConfig.RestartSec;
  runnerAdmissionScript = lib.removePrefix "+" (
    builtins.head runnerService.serviceConfig.ExecStartPre
  );
  runnerNixDaemonEnabled =
    (runnerConfig.systemd.services.nix-daemon.enable or false)
    || (runnerConfig.systemd.sockets.nix-daemon.enable or false);
  runnerLegacyText = lib.concatStringsSep "\n" [
    runnerContainerOptions
    (runnerService.environment.NIX_REMOTE or "")
    runnerNixVolumeScript
  ];
  hostConfig = nixosConfigurations.server-legion.config;
  hostServices = hostConfig.systemd.services;
  stateRootUnit = hostServices.homelab-state-root;
  stateRepairUnits = map (name: hostServices."homelab-state-${name}") [
    "jellyfin"
    "radarr"
    "sonarr"
  ];
  nixflixSetupUnit = hostServices.nixflix-setup-dirs;
  forgejoSnapshotUnit = hostServices.homelab-forgejo-snapshot;
  runnerVmUnit = hostServices."microvm@forgejo-runner";
  runnerProxyUnit = hostServices.forgejo-runner-proxy-global;
  runnerEgressUnit = hostServices.forgejo-runner-egress-global;
  runnerEgressExecStart = runnerEgressUnit.serviceConfig.ExecStart;
in
{
  "homelab-state-root-regression" = pkgs.runCommand "homelab-state-root-regression" { } ''
    rootTmpfiles=${lib.escapeShellArg (lib.concatStringsSep "\n" hostConfig.systemd.tmpfiles.rules)}
    rootRequires=${lib.escapeShellArg (lib.concatStringsSep "\n" stateRootUnit.requires)}
    rootAfter=${lib.escapeShellArg (lib.concatStringsSep "\n" stateRootUnit.after)}
    rootMounts=${lib.escapeShellArg (lib.concatStringsSep "\n" stateRootUnit.unitConfig.RequiresMountsFor)}
    rootScript=${lib.escapeShellArg stateRootUnit.script}
    nixflixRequires=${lib.escapeShellArg (lib.concatStringsSep "\n" nixflixSetupUnit.requires)}
    nixflixAfter=${lib.escapeShellArg (lib.concatStringsSep "\n" nixflixSetupUnit.after)}
    nixflixScript=${lib.escapeShellArg nixflixSetupUnit.script}
    snapshotRequires=${lib.escapeShellArg (lib.concatStringsSep "\n" forgejoSnapshotUnit.requires)}
    snapshotAfter=${lib.escapeShellArg (lib.concatStringsSep "\n" forgejoSnapshotUnit.after)}
    snapshotScript=${lib.escapeShellArg forgejoSnapshotUnit.script}
    contains() {
      ${pkgs.gnugrep}/bin/grep -Fqx "$1" <<<"$2"
    }
    contains 'd /var/lib/homelab 0755 root root - -' "$rootTmpfiles"
    contains 'z /var/lib/homelab 0755 root root - -' "$rootTmpfiles"
    contains local-fs.target "$rootRequires"
    contains local-fs.target "$rootAfter"
    contains /var/lib/homelab "$rootMounts"
    ${pkgs.gnugrep}/bin/grep -F 'chown root:root "$state_root"' "$rootScript"
    ${pkgs.gnugrep}/bin/grep -F 'chmod 0755 "$state_root"' "$rootScript"
    if ${pkgs.gnugrep}/bin/grep -F 'chown -R' "$rootScript"; then
      exit 1
    fi
    contains homelab-state-root.service "$nixflixRequires"
    contains homelab-state-root.service "$nixflixAfter"
    contains homelab-state-root.service "$snapshotRequires"
    contains homelab-state-root.service "$snapshotAfter"
    ${pkgs.gnugrep}/bin/grep -F -- '--prefix=/var/lib/homelab' <<<"$nixflixScript"
    ${pkgs.gnugrep}/bin/grep -F 'mkdir -m 0700 /var/lib/homelab/forgejo-backup.new' <<<"$snapshotScript"
    if ${pkgs.gnugrep}/bin/grep -F 'install -d -m 0700 /var/lib/homelab' <<<"$snapshotScript"; then
      exit 1
    fi
    ${lib.concatMapStringsSep "\n" (unit: ''
      repairRequires=${lib.escapeShellArg (lib.concatStringsSep "\n" unit.requires)}
      repairAfter=${lib.escapeShellArg (lib.concatStringsSep "\n" unit.after)}
      contains homelab-state-root.service "$repairRequires"
      contains homelab-state-root.service "$repairAfter"
    '') stateRepairUnits}
    touch "$out"
  '';

  "runner-image-layout-regression" = pkgs.runCommand "runner-image-layout-regression" { } ''
    test "${toString (builtins.length runnerImages)}" = 1
    test "${lib.escapeShellArg (builtins.head runnerImages).reference}" = "forgejo-runner-nix:${pkgs.nix.version}"
    test "${toString (builtins.length runnerLabels)}" = 3
    labels=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerLabels)}
    ${pkgs.gnugrep}/bin/grep -Fqx "forgejo-ci:docker://forgejo-runner-nix:${pkgs.nix.version}" <<<"$labels"
    ${pkgs.gnugrep}/bin/grep -Fqx "ubuntu-latest:docker://forgejo-runner-nix:${pkgs.nix.version}" <<<"$labels"
    ${pkgs.gnugrep}/bin/grep -Fqx "nix:docker://forgejo-runner-nix:${pkgs.nix.version}" <<<"$labels"
    if ${pkgs.gnugrep}/bin/grep -Fq forgejo-runner-node <<<"$labels"; then
      exit 1
    fi
    touch "$out"
  '';

  "runner-nix-proxy-regression" = pkgs.runCommand "runner-nix-proxy-regression" { } ''
    set -euo pipefail
    root="$TMPDIR/nix"
    state="$TMPDIR/state"
    mkdir -p "$root/nix/store" "$root/nix/var/nix" "$state"
    export NIX_STATE_DIR="$state"
    ${pkgs.nix}/bin/nix-store --init --store "local?root=$root"
    cat >"$TMPDIR/proxy.nix" <<'EOF'
    derivation {
      name = "forgejo-proxy-environment";
      system = "${system}";
      builder = "/bin/sh";
      args = [ "-c" "test \"$HTTP_PROXY\" = \"http://10.203.0.1:18081\"; test \"$HTTPS_PROXY\" = \"http://10.203.0.1:18081\"; test \"$http_proxy\" = \"http://10.203.0.1:18081\"; test \"$https_proxy\" = \"http://10.203.0.1:18081\"; test \"$NO_PROXY\" = \"127.0.0.1,localhost,10.203.0.1,10.203.0.2\"; test \"$no_proxy\" = \"127.0.0.1,localhost,10.203.0.1,10.203.0.2\"; printf 'proxy-forwarded\\n' > \"$out\"" ];
      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = "7945d360a957e926a4c3e293d365d9900f324afa6ea7edbb4395eb06aae48243";
    }
    EOF
    HTTP_PROXY=http://10.203.0.1:18081 HTTPS_PROXY=http://10.203.0.1:18081 NO_PROXY=127.0.0.1,localhost,10.203.0.1,10.203.0.2 http_proxy=http://10.203.0.1:18081 https_proxy=http://10.203.0.1:18081 no_proxy=127.0.0.1,localhost,10.203.0.1,10.203.0.2 \
      ${pkgs.nix}/bin/nix-build \
        --store "local?root=$root" \
        --option sandbox false \
        --option build-users-group "" \
        "$TMPDIR/proxy.nix" >/dev/null
    touch "$out"
  '';

  "runner-docker-observer-regression" = pkgs.runCommand "runner-docker-observer-regression" { } ''
    script=${lib.escapeShellArg runnerDockerObserverScript}
    ${pkgs.gnugrep}/bin/grep -F 'docker events --filter type=container' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'create|start|die|destroy' "$script"
    if ${pkgs.gnugrep}/bin/grep -Eq '\$docker logs|bounded PostgreSQL logs|\[redacted\]' "$script"; then
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -F 'storeRoot=/var/lib/forgejo-nix/volume/store' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'persistent store metadata' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'if [ -n "$volumeInfo" ]; then' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'observe_active_store_tmp()' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'active persistent store temporary metadata' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'observe_active_store_tmp &' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'event stream starting' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'event stream ended status=$eventStatus; retrying' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'coproc dockerEvents {' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'while IFS= read -r event <&"''${dockerEvents[0]}"; do' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'eventStreamPid="''${dockerEvents_PID}"' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'if wait "$eventStreamPid"; then' "$script"
    if ${pkgs.gnugrep}/bin/grep -F '$docker events --filter type=container --format' "$script" | ${pkgs.gnugrep}/bin/grep -Fq '| while'; then
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -F 'ignored unparseable container event' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'sleep 2' "$script"
    if ${pkgs.gnugrep}/bin/grep -Fq 'event listener health' "$script"; then
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -F 'security-options=' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'volume={{.Name}} destination={{.Destination}} rw={{.RW}}' "$script"
    ${pkgs.gnugrep}/bin/grep -F 'cap-add={{json .HostConfig.CapAdd}} cap-drop={{json .HostConfig.CapDrop}}' "$script"
    if ${pkgs.gnugrep}/bin/grep -Eq '\$docker inspect "\$id"|\.Config\.Env|/workspace' "$script"; then
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Eq '(/bin/rm|/bin/chmod|/bin/chown|/bin/mv)' "$script"; then
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Eq -- '--cap-(add|drop)=' <<<${lib.escapeShellArg runnerContainerOptions}; then
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Fq -- '--env=PATH=' <<<${lib.escapeShellArg runnerContainerOptions}; then
      exit 1
    fi
    test "${runnerContainerDockerHost}" = -
    test "${if runnerContainerPrivileged then "true" else "false"}" = false
    test "${runnerDockerObserverRestart}" = always
    test "${runnerDockerObserverRestartSec}" = 1s
    observerRequires=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerDockerObserver.requires)}
    observerBefore=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerDockerObserver.before)}
    ${pkgs.gnugrep}/bin/grep -F 'docker.service' <<<"$observerRequires"
    ${pkgs.gnugrep}/bin/grep -F 'gitea-runner-global.service' <<<"$observerBefore"
    touch "$out"
  '';

  "runner-availability-regression" = pkgs.runCommand "runner-availability-regression" { } ''
    vmRequires=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerVmUnit.requires)}
    vmAfter=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerVmUnit.after)}
    vmWants=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerVmUnit.wants)}
    proxyRequires=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerProxyUnit.requires)}
    proxyAfter=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerProxyUnit.after)}
    egressRequires=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerEgressUnit.requires)}
    egressAfter=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerEgressUnit.after)}
    contains() {
      ${pkgs.gnugrep}/bin/grep -Fqx "$1" <<<"$2"
    }
    contains forgejo-runner-firewall-guard.service "$vmRequires"
    contains forgejo-runner-proxy-global.service "$vmRequires"
    contains forgejo-runner-firewall-guard.service "$vmAfter"
    contains forgejo-runner-proxy-global.service "$vmAfter"
    contains forgejo-runner-egress-global.service "$vmWants"
    contains microvm-tap-interfaces@forgejo-runner.service "$proxyRequires"
    contains microvm-tap-interfaces@forgejo-runner.service "$proxyAfter"
    contains microvm-tap-interfaces@forgejo-runner.service "$egressRequires"
    contains microvm-tap-interfaces@forgejo-runner.service "$egressAfter"
    if contains forgejo-runner-egress-global.service "$vmRequires" || contains forgejo-runner-egress-global.service "$vmAfter"; then
      exit 1
    fi
    touch "$out"
  '';

  "recovery-service-regression" = pkgs.runCommand "recovery-service-regression" { } ''
    recoveryScript=${lib.escapeShellArg recoveryScript}
    ${pkgs.gnugrep}/bin/grep -F 'e2fsck -fn "$dockerImage" || oldFsckStatus=$?' "$recoveryScript"
    ${pkgs.gnugrep}/bin/grep -F 'case "$oldFsckStatus" in' "$recoveryScript"
    if ${pkgs.gnugrep}/bin/grep -F fuser "$recoveryScript"; then
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -F 'if ! e2fsck' "$recoveryScript"; then
      exit 1
    fi

    probe="$(
      ${pkgs.gnugrep}/bin/grep -Eo '/nix/store/[a-z0-9]+-forgejo-runner-open-handle-probe' "$recoveryScript" \
        | ${pkgs.coreutils}/bin/head -n 1
    )"
    test -x "$probe"

    image="$TMPDIR/docker.raw"
    procRoot="$TMPDIR/proc"
    mkdir -p "$procRoot/100/fd"
    touch "$image"

    probeStatus=0
    "$probe" "$image" "$procRoot" || probeStatus=$?
    test "$probeStatus" -eq 0

    ln -s "$image" "$procRoot/100/fd/3"
    probeStatus=0
    "$probe" "$image" "$procRoot" || probeStatus=$?
    test "$probeStatus" -eq 1
    rm "$procRoot/100/fd/3"

    rmdir "$procRoot/100/fd"
    probeStatus=0
    "$probe" "$image" "$procRoot" || probeStatus=$?
    test "$probeStatus" -eq 2

    probeLine="$(${pkgs.gnugrep}/bin/grep -nF 'forgejo-runner-open-handle-probe "$dockerImage" /proc' "$recoveryScript" | ${pkgs.coreutils}/bin/cut -d: -f1)"
    stagingLine="$(${pkgs.gnugrep}/bin/grep -nF 'btrfs subvolume create "$stagingSubvolume"' "$recoveryScript" | ${pkgs.coreutils}/bin/cut -d: -f1)"
    renameLine="$(${pkgs.gnugrep}/bin/grep -nF 'mv -- "$dockerSubvolume" "$retired"' "$recoveryScript" | ${pkgs.coreutils}/bin/cut -d: -f1)"
    test "$probeLine" -lt "$stagingLine"
    test "$probeLine" -lt "$renameLine"

    touch "$out"
  '';

  "runner-nix-image-regression" =
    pkgs.runCommand "runner-nix-image-regression"
      {
        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.gzip
          pkgs.jq
          pkgs.binutils
        ];
      }
      ''
        set -o pipefail
        state="$(mktemp -d)"
        firstTree="$state/first-nix.tree"
        volumeRoot="$state/volume"
        containerRoot="$state/container"
        mkdir "$containerRoot"
        tree_manifest() {
          tree="$1"
          ${pkgs.coreutils}/bin/stat -c 'd %a %u %g %Y %s' -- "$tree"
          entries="$(mktemp)"
          ${pkgs.findutils}/bin/find "$tree" -mindepth 1 -printf '%P\0' \
            | ${pkgs.coreutils}/bin/sort -z >"$entries"
          while IFS= read -r -d $'\0' entry; do
            item="$tree/$entry"
            metadata="$(${pkgs.coreutils}/bin/stat -c '%a %u %g %Y %s' -- "$item")"
            if [ -L "$item" ]; then
              printf 'l %s %s %s\n' "$entry" "$metadata" "$(readlink -- "$item")"
            elif [ -d "$item" ]; then
              printf 'd %s %s\n' "$entry" "$metadata"
            elif [ -f "$item" ]; then
              hash="$(${pkgs.coreutils}/bin/sha256sum -- "$item")"
              printf 'f %s %s %s\n' "$entry" "$metadata" "''${hash%% *}"
            else
              exit 1
            fi
          done <"$entries"
          rm "$entries"
        }
        verify_store_paths() {
          storeRoot="$1/store"
          while IFS= read -r storePath; do
            path="/nix/store/$(basename "$storePath")"
            env USER=nobody NIX_REMOTE="local?root=$volumeRoot" ${pkgs.nix}/bin/nix-store --verify-path "$path"
          done < <(${pkgs.findutils}/bin/find "$storeRoot" -mindepth 1 -maxdepth 1 ! -name .links -print)
        }
        ${lib.concatMapStringsSep "\n" (image: ''
          image=${lib.escapeShellArg image.archive}
          reference=${lib.escapeShellArg image.reference}
          root="$(mktemp -d)"
          ${pkgs.gnutar}/bin/tar -xOzf "$image" manifest.json >"$root/manifest.json"
          jq -e --arg reference "$reference" '
            map(select((.RepoTags // []) | index($reference)))
            | if length == 1 then .[0] else error("expected one matching image") end
          ' "$root/manifest.json" >"$root/selected.json"
          configFile="$(jq -er '.Config' "$root/selected.json")"
          ${pkgs.gnutar}/bin/tar -xOzf "$image" "$configFile" >"$root/config.json"
          jq -e --arg path 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
            '.config.Env | index($path) != null' "$root/config.json"
          jq -e '.config.User == null or .config.User == ""' "$root/config.json"
          if jq -e '.config.Env | any(startswith("NIX_REMOTE="))' "$root/config.json"; then
            exit 1
          fi
          mkdir "$root/fs"
          jq -er '.Layers[]' "$root/selected.json" | while IFS= read -r layer; do
            ${pkgs.gnutar}/bin/tar -xOzf "$image" "$layer" >"$root/layer"
            while IFS= read -r member; do
              member="''${member#./}"
              case "$member" in
                .wh.nix|.wh..wh..opq|nix/.wh.*|nix/*/.wh.*) exit 1 ;;
              esac
            done < <(${pkgs.gnutar}/bin/tar -tf "$root/layer")
            ${pkgs.gnutar}/bin/tar --no-overwrite-dir -xf "$root/layer" -C "$root/fs"
          done
          test -f "$root/fs/etc/passwd"
          ${pkgs.gnugrep}/bin/grep -Eq '^root:[^:]*:0:0:[^:]*:/root:[^:]*$' "$root/fs/etc/passwd"
          test -d "$root/fs/root"
          nixRoot="$root/fs/nix"
          nodeElf="$root/fs/usr/local/bin/node"
          test -x "$nodeElf"
          interpreter="$(${pkgs.binutils}/bin/readelf -lW "$nodeElf" | ${pkgs.gnugrep}/bin/grep -oE 'Requesting program interpreter: [^]]+' | ${pkgs.coreutils}/bin/cut -d ' ' -f4)"
          test "$interpreter" = /lib64/ld-linux-x86-64.so.2
          fhsLoader="$root/fs$interpreter"
          while [ -L "$fhsLoader" ]; do
            target="$(${pkgs.coreutils}/bin/readlink "$fhsLoader")"
            case "$target" in
              /*) fhsLoader="$root/fs$target" ;;
              *) fhsLoader="$(${pkgs.coreutils}/bin/dirname "$fhsLoader")/$target" ;;
            esac
          done
          test -x "$fhsLoader"
          test ! -L "$root/fs/usr/bin"
          test -L "$root/fs/usr/bin/sh"
          test -x "$root/fs/usr/bin/dash"
          test -x "$root/fs/usr/bin/bash"
          test -d "$nixRoot/store"
          test -s "$nixRoot/var/nix/db/db.sqlite"
          test -d "$nixRoot/var/nix/gcroots/docker"
          test -f "$nixRoot/.forgejo-nix-seed-epoch"
          test ! -L "$nixRoot/.forgejo-nix-seed-epoch"
          test "$(< "$nixRoot/.forgejo-nix-seed-epoch")" = ${lib.escapeShellArg runnerSeedEpoch}
          test ! -e "$root/fs/nix-cache"
          test ! -e "$nixRoot/var/nix/daemon-socket"
          seedPath="$(${pkgs.findutils}/bin/find "$nixRoot/store" -mindepth 1 -maxdepth 1 -type d -name '*-forgejo-runner-nix-seed' -print -quit)"
          test -n "$seedPath"
          test -z "$(${pkgs.findutils}/bin/find "$nixRoot/store" -mindepth 1 -maxdepth 1 -name '*nodejs-22*' -print -quit)"
          tree_manifest "$nixRoot" >"$root/nix.tree"
          if [ ! -e "$firstTree" ]; then
            cp "$root/nix.tree" "$firstTree"
            mkdir "$volumeRoot"
            cp -a "$nixRoot" "$volumeRoot/"
            volume="$volumeRoot/nix"
            ln -s "$volume" "$containerRoot/nix"
          else
            cmp "$firstTree" "$root/nix.tree"
          fi
          verify_store_paths "$nixRoot"
          test -f "$root/fs/etc/nix/nix.conf"
          ${pkgs.gnugrep}/bin/grep -F 'substituters = https://cache.nixos.org/' "$root/fs/etc/nix/nix.conf"
          ${pkgs.gnugrep}/bin/grep -F 'trusted-public-keys = cache.nixos.org-1:' "$root/fs/etc/nix/nix.conf"
          ${pkgs.gnugrep}/bin/grep -F 'sandbox = false' "$root/fs/etc/nix/nix.conf"
          ${pkgs.gnugrep}/bin/grep -Fx 'build-users-group =' "$root/fs/etc/nix/nix.conf"
          ${pkgs.gnugrep}/bin/grep -F 'min-free = 4294967296' "$root/fs/etc/nix/nix.conf"
          ${pkgs.gnugrep}/bin/grep -F 'max-free = 8589934592' "$root/fs/etc/nix/nix.conf"
          ${pkgs.gnugrep}/bin/grep -F 'post-build-hook = /bin/forgejo-nix-cleanup' "$root/fs/etc/nix/nix.conf"
          test ! -e "$root/fs/homeless-shelter"
          cleanupHook="$(${pkgs.findutils}/bin/find "$root/fs/nix/store" -path '*/bin/forgejo-nix-cleanup' -print -quit)"
          test -n "$cleanupHook"
          cleanupTarget="$(${pkgs.coreutils}/bin/readlink --canonicalize-existing "$cleanupHook")"
          test -x "$cleanupTarget"
          testRoot="/tmp/forgejo-nix-cleanup-regression"
          ${pkgs.coreutils}/bin/rm -rf -- "$testRoot"
          trap '${pkgs.coreutils}/bin/rm -rf -- "$testRoot"' EXIT
          nestedRoot="$testRoot/nested-nix"
          failureRoot="$testRoot/failure-nix"
          mkdir -p "$nestedRoot/nix/store" "$nestedRoot/nix/var/nix"
          mkdir -p "$failureRoot/nix/store" "$failureRoot/nix/var/nix"
          cat >"$state/first.nix" <<'EOF'
          derivation {
            name = "forgejo-cleanup-first";
            system = "__SYSTEM__";
            builder = "/bin/sh";
            args = [ "-c" ": > \"$TEST_ROOT/homeless-shelter\"; printf first > $out" ];
            TEST_ROOT = "__TEST_ROOT__";
          }
          EOF
          cat >"$state/second.nix" <<'EOF'
          derivation {
            name = "forgejo-cleanup-second";
            system = "__SYSTEM__";
            builder = "/bin/sh";
            args = [ "-c" "test ! -e \"$TEST_ROOT/homeless-shelter\"; printf second > $out" ];
            TEST_ROOT = "__TEST_ROOT__";
          }
          EOF
          ${pkgs.gnused}/bin/sed -i \
            -e "s#__SYSTEM__#${system}#g" \
            -e "s#__TEST_ROOT__#$testRoot#g" \
            "$state/first.nix" "$state/second.nix"
          export NIX_STATE_DIR="$state/nix-state"
          export NIX_LOG_DIR="$state/nix-log"
          mkdir -p "$NIX_STATE_DIR" "$NIX_LOG_DIR"
          ${pkgs.nix}/bin/nix-store --init --store "local?root=$failureRoot"
          if ${pkgs.nix}/bin/nix-build \
            --store "local?root=$failureRoot" \
            --option sandbox false \
            --option build-users-group "" \
            --option post-build-hook "${pkgs.coreutils}/bin/false" \
            "$state/first.nix" >/dev/null 2>&1; then
            exit 1
          fi
          ${pkgs.nix}/bin/nix-store --init --store "local?root=$nestedRoot"
          for path in ${cleanupTestHook} ${pkgs.bash} ${pkgs.coreutils}; do
            ${pkgs.coreutils}/bin/cp -a -- "$path" "$nestedRoot/nix/store/"
          done
          ${pkgs.nix}/bin/nix-build \
            --store "local?root=$nestedRoot" \
            --option sandbox false \
            --option build-users-group "" \
            --option post-build-hook "${cleanupTestHook}" \
            "$state/first.nix" >/dev/null
          test ! -e "$testRoot/homeless-shelter"
          ${pkgs.nix}/bin/nix-build \
            --store "local?root=$nestedRoot" \
            --option sandbox false \
            --option build-users-group "" \
            --option post-build-hook "${cleanupTestHook}" \
            "$state/second.nix" >/dev/null
          test -e "$root/fs/usr/bin"
          for command in tail bash git nix; do
            test -L "$root/fs/bin/$command"
            test -L "$root/fs/usr/bin/$command"
            target="$(readlink "$root/fs/bin/$command")"
            while test -L "$root/fs$target"; do
              link="$(readlink "$root/fs$target")"
              case "$link" in
                /*) target="$link" ;;
                *) target="$(dirname "$target")/$link" ;;
              esac
            done
            case "$target" in
              /nix/store/*) ;;
              *) exit 1 ;;
            esac
            test -x "$root/fs$target"
          done
        '') runnerImages}
        test -f "$volume/.forgejo-nix-seed-epoch"
        test ! -L "$volume/.forgejo-nix-seed-epoch"
        test "$(< "$volume/.forgejo-nix-seed-epoch")" = ${lib.escapeShellArg runnerSeedEpoch}
        dbHash="$(${pkgs.coreutils}/bin/sha256sum "$volume/var/nix/db/db.sqlite")"
        printf 'reused\n' >"$containerRoot/nix/.docker-volume-reused"
        test -f "$volume/.docker-volume-reused"
        test "$dbHash" = "$(${pkgs.coreutils}/bin/sha256sum "$volume/var/nix/db/db.sqlite")"
        verify_store_paths "$volume"
        touch "$out"
      '';

  "runner-service-regression" = pkgs.runCommand "runner-service-regression" { } ''
    set -euo pipefail
    path=${lib.escapeShellArg runnerService.environment.PATH}
    execStart=${lib.escapeShellArg runnerService.serviceConfig.ExecStart}
    containerOptions=${lib.escapeShellArg runnerContainerOptions}
    validVolumes=${lib.escapeShellArg (lib.concatStringsSep " " runnerValidVolumes)}
    containerPrivileged=${lib.escapeShellArg (if runnerContainerPrivileged then "true" else "false")}
    containerDockerHost=${lib.escapeShellArg runnerContainerDockerHost}
    runnerHome=${lib.escapeShellArg (runnerEnvs.HOME or "")}
    runnerHttpProxy=${lib.escapeShellArg (runnerEnvs.HTTP_PROXY or "")}
    runnerHttpsProxy=${lib.escapeShellArg runnerHttpsProxy}
    runnerNoProxy=${lib.escapeShellArg runnerNoProxy}
    runnerHttpProxyLower=${lib.escapeShellArg runnerHttpProxyLower}
    runnerHttpsProxyLower=${lib.escapeShellArg runnerHttpsProxyLower}
    runnerNoProxyLower=${lib.escapeShellArg runnerNoProxyLower}
    dockerHttpProxy=${lib.escapeShellArg (runnerDockerProxies."http-proxy" or "")}
    dockerHttpsProxy=${lib.escapeShellArg (runnerDockerProxies."https-proxy" or "")}
    dockerNoProxy=${lib.escapeShellArg (runnerDockerProxies."no-proxy" or "")}
    dockerHome=${lib.escapeShellArg (runnerDockerProxies.HOME or "")}
    httpProxy=${lib.escapeShellArg (runnerService.environment.HTTP_PROXY or "")}
    admissionScript=${lib.escapeShellArg runnerAdmissionScript}
    volumeScript=${lib.escapeShellArg runnerNixVolumeScript}
    resetScript=${lib.escapeShellArg runnerCacheResetScript}
    migrationScript=${lib.escapeShellArg runnerCacheMigrationScript}
    legacyText=${lib.escapeShellArg runnerLegacyText}
    egressExecStart=${lib.escapeShellArg runnerEgressExecStart}
    nixDaemonEnabled=${lib.escapeShellArg (if runnerNixDaemonEnabled then "true" else "false")}
    test "$nixDaemonEnabled" = false
    test "$containerPrivileged" = false
    test "$containerDockerHost" = -
    test "$containerOptions" = "--security-opt=no-new-privileges --mount type=volume,src=forgejo-nix,dst=/nix"
    test -z "$runnerHome"
    test "$runnerHttpProxy" = "http://10.203.0.1:18081"
    test "$runnerHttpsProxy" = "http://10.203.0.1:18081"
    test "$runnerNoProxy" = "127.0.0.1,localhost,10.203.0.1,10.203.0.2"
    test "$runnerHttpProxyLower" = "http://10.203.0.1:18081"
    test "$runnerHttpsProxyLower" = "http://10.203.0.1:18081"
    test "$runnerNoProxyLower" = "127.0.0.1,localhost,10.203.0.1,10.203.0.2"
    test "$dockerHttpProxy" = "http://10.203.0.1:18081"
    test "$dockerHttpsProxy" = "http://10.203.0.1:18081"
    test "$dockerNoProxy" = "127.0.0.1,localhost,10.203.0.1,10.203.0.2"
    test -z "$dockerHome"
    test "$validVolumes" = "forgejo-nix"
    test "$httpProxy" = "http://10.203.0.1:18081"
    egressConfig="$(${pkgs.gnugrep}/bin/grep -oE '/nix/store/[^ ]+\.conf' <<<"$egressExecStart" | ${pkgs.coreutils}/bin/head -n 1)"
    test -n "$egressConfig"
    ${pkgs.gnugrep}/bin/grep -Fx 'acl runner_connections maxconn 256' "$egressConfig"
    ${pkgs.gnugrep}/bin/grep -Fx 'acl egress_errors http_status 400-599' "$egressConfig"
    ${pkgs.gnugrep}/bin/grep -Fx 'logformat egress_error %ts.%03tu %>a %rm %ru %>Hs' "$egressConfig"
    ${pkgs.gnugrep}/bin/grep -Fx 'access_log stdio:/dev/stderr egress_error egress_errors' "$egressConfig"
    if ${pkgs.gnugrep}/bin/grep -F 'access_log none' "$egressConfig"; then
      exit 1
    fi
    case "$execStart" in
      */bin/forgejo-runner\ daemon\ --config\ *) ;;
      *) exit 1 ;;
    esac
    if ${pkgs.gnugrep}/bin/grep -E '(nix-daemon|daemon-socket|NIX_REMOTE|local\\?store=|/nix-cache/store|/nix-cache/var)' <<<"$legacyText"; then
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -F 'docker volume create --driver local --opt type=none --opt o=bind --opt device=/var/lib/forgejo-nix/volume forgejo-nix' "$volumeScript"
    ${pkgs.gnugrep}/bin/grep -F -- '--mount type=volume,src=forgejo-nix,dst=/nix' <<<"$containerOptions"
    ${pkgs.gnugrep}/bin/grep -F 'forgejo-nix-seed-epoch' "$volumeScript"
    ${pkgs.gnugrep}/bin/grep -F 'must remain masked' "$resetScript"
    ${pkgs.gnugrep}/bin/grep -F 'must remain masked' "$migrationScript"
    ${pkgs.gnugrep}/bin/grep -F 'oldBytes' "$migrationScript"
    ${pkgs.gnugrep}/bin/grep -F 'mindepth 1 -maxdepth 1 -print -quit' "$volumeScript"
    test "$(${pkgs.gnugrep}/bin/grep -Ec '/nix/store/[a-z0-9]+-coreutils-[^/]+/bin/df --output=avail' "$admissionScript")" -eq 3
    test "$(${pkgs.gnugrep}/bin/grep -Ec '\\| /nix/store/[a-z0-9]+-coreutils-[^/]+/bin/tail -n 1' "$admissionScript")" -eq 3
    test "$(${pkgs.gnugrep}/bin/grep -Ec '\\| /nix/store/[a-z0-9]+-coreutils-[^/]+/bin/tr -d' "$admissionScript")" -eq 3
    if ${pkgs.gnugrep}/bin/grep -F '$(df --output=avail' "$admissionScript"; then
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -F '| tail -n 1' "$admissionScript"; then
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -F '| tr -d' "$admissionScript"; then
      exit 1
    fi
    test ${toString runnerActions.nixCacheMinFreeMiB} -eq 4096
    test ${toString runnerActions.nixCacheMaxFreeMiB} -eq 8192
    test ${toString runnerActions.runners.global.resources.nixCacheMiB} -eq 65536
    test ${toString runnerActions.runners.global.resources.qgroupLimitBudgetMiB} -eq 98304
    touch "$out"
  '';

  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = ./.;
    default_stages = [ "pre-commit" ];
    hooks = {
      # ========== General ==========
      check-added-large-files = {
        enable = true;
        excludes = [
          "\\.png"
          "\\.jpg"
        ];
      };
      check-case-conflicts.enable = true;
      check-executables-have-shebangs.enable = true;
      check-shebang-scripts-are-executable.enable = false; # many of the scripts in the config aren't executable because they don't need to be.
      check-merge-conflicts.enable = true;
      detect-private-keys.enable = true;
      fix-byte-order-marker.enable = true;
      mixed-line-endings.enable = true;
      trim-trailing-whitespace.enable = true;
      end-of-file-fixer.enable = true;

      # ========== nix ==========
      nixfmt.enable = true;
      deadnix = {
        enable = true;
        settings = {
          noLambdaArg = true;
        };
      };
      statix.enable = true;
    };
  };
}
// hostChecks
