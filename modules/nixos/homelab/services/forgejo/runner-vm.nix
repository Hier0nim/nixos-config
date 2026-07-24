{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  forgejoCfg = cfg.services.forgejo;
  runnerCfg = forgejoCfg.actions;
  runnerEnabled = cfg.enable && forgejoCfg.enable;
  iptables = "${pkgs.iptables}/bin/iptables --wait 30";
  ip6tables = "${pkgs.iptables}/bin/ip6tables --wait 30";

  enabledRunners = lib.filterAttrs (_: runner: runner.enable) runnerCfg.runners;
  runnerNames = builtins.attrNames enabledRunners;

  mkRunnerData = name: runner: {
    inherit name runner;
    inherit (runner)
      vmName
      hostAddress
      guestAddress
      ;
    subnetAddress = lib.removeSuffix "/30" runner.subnet;
    storageDir = "/var/lib/microvms/forgejo-runner-storage-${name}";
    vmStateDir = "/var/lib/microvms/${runner.vmName}";
    stateSubvolume = "/var/lib/microvms/forgejo-runner-storage-${name}";
    nixCacheSubvolume = "/var/lib/microvms/forgejo-runner-storage-${name}/nix-cache";
    dockerSubvolume = "/var/lib/microvms/forgejo-runner-storage-${name}/docker";
    workSubvolume = "/var/lib/microvms/forgejo-runner-storage-${name}/work";
    stateImage = "/var/lib/microvms/forgejo-runner-storage-${name}/var.raw";
    nixCacheImage = "/var/lib/microvms/forgejo-runner-storage-${name}/nix-cache/nix-cache.raw";
    dockerImage = "/var/lib/microvms/forgejo-runner-storage-${name}/docker/docker.raw";
    recoveryInterlock = "/var/lib/microvms/forgejo-runner-storage-${name}/.docker-recovery-interlock";
    resetInterlock = "/var/lib/microvms/forgejo-runner-reset-interlock-${name}";
    nixCacheMigrationInterlock = "/var/lib/microvms/forgejo-runner-storage-${name}/.nix-cache-migration-required";
    nixCacheGuardService = "forgejo-runner-nix-cache-guard-${name}";
    workImage = "/var/lib/microvms/forgejo-runner-storage-${name}/work/work.raw";
    images = map (imageName: runnerCfg.images.${imageName}) runner.runner.imageNames;
    proxyService = "forgejo-runner-proxy-${name}";
    storageService = "forgejo-runner-storage-${name}";
    egressService = "forgejo-runner-egress-${name}";
  };

  runners = lib.mapAttrs mkRunnerData enabledRunners;
  runnerData = builtins.attrValues runners;

  ipv4Octets = address: map lib.toInt (lib.splitString "." address);
  runnerNetworkValid =
    data:
    let
      network = ipv4Octets data.subnetAddress;
      host = ipv4Octets data.hostAddress;
      guest = ipv4Octets data.guestAddress;
      networkLast = builtins.elemAt network 3;
    in
    lib.take 3 network == lib.take 3 host
    && lib.take 3 network == lib.take 3 guest
    && builtins.bitAnd networkLast 3 == 0
    && networkLast <= 252
    && builtins.elemAt host 3 == networkLast + 1
    && builtins.elemAt guest 3 == networkLast + 2;

  labelImage =
    label:
    let
      match = builtins.match "^[^:]+:docker://([^?]+)(\\?.*)?$" label;
    in
    if match == null then null else builtins.head match;

  runnerLabelsValid =
    data:
    let
      imageReferences = map (image: image.reference) data.images;
    in
    data.runner.runner.labels != [ ]
    && lib.all (label: builtins.elem (labelImage label) imageReferences) data.runner.runner.labels;
  runnerNixSeedValid =
    data:
    data.runner.runner.nixSeedEpoch != ""
    && lib.all (image: image.nixSeedEpoch == data.runner.runner.nixSeedEpoch) data.images;

  mkCaddyfile =
    data:
    pkgs.writeText "${data.proxyService}.Caddyfile" ''
      {
        admin off
        auto_https off
      }

      http://${data.hostAddress}:${toString data.runner.forgejoProxyPort} {
        reverse_proxy 127.0.0.1:3000
      }
    '';

  blockedDestinationRanges = [
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.0.0.0/24"
    "192.0.2.0/24"
    "192.88.99.0/24"
    "192.168.0.0/16"
    "198.18.0.0/15"
    "198.51.100.0/24"
    "203.0.113.0/24"
    "224.0.0.0/4"
    "240.0.0.0/4"
    "::/128"
    "::1/128"
    "100::/64"
    "64:ff9b::/96"
    "64:ff9b:1::/48"
    "2001::/32"
    "2002::/16"
    "2001:db8::/32"
    "fc00::/7"
    "fe80::/10"
    "ff00::/8"
  ];
  mkEgressConfig =
    data:
    pkgs.writeText "${data.egressService}.conf" ''
      http_port ${data.hostAddress}:${toString data.runner.egress.proxyPort}
      acl runner src ${data.guestAddress}/32
      acl CONNECT method CONNECT
      acl SSL_ports port 443
      acl forbidden_dst dst ${lib.concatStringsSep " " blockedDestinationRanges}
      acl runner_connections maxconn 64
      http_access deny !runner
      http_access deny runner_connections
      http_access deny !CONNECT
      http_access deny !SSL_ports
      http_access deny forbidden_dst
      http_access allow runner
      http_access deny all
      dns_nameservers 1.1.1.1 9.9.9.9
      cache deny all
      acl egress_errors http_status 400-599
      logformat egress_error %ts.%03tu client=%>a method=%>rm squid=%Ss status=%>Hs
      access_log stdio:/run/${data.egressService}/egress-errors.log egress_error egress_errors
      cache_store_log none
      cache_log stdio:/dev/null
      logfile_rotate 0
      forwarded_for delete
      shutdown_lifetime 1 seconds
      connect_timeout 30 seconds
      request_timeout 5 minutes
      read_timeout 15 minutes
      pid_filename none
    '';

  forwardChain = "nixos-fj-runner";
  dockerUserChain = "nixos-fj-runner-docker";

  removeFirewallInputRules = data: ''
    while ${iptables} -D nixos-fw -i ${data.runner.tapName} -s ${data.guestAddress} -d ${data.hostAddress} -p tcp --dport ${toString data.runner.forgejoProxyPort} -j ACCEPT 2>/dev/null; do :; done
    ${lib.optionalString data.runner.egress.enable ''
      while ${iptables} -D nixos-fw -i ${data.runner.tapName} -s ${data.guestAddress} -d ${data.hostAddress} -p tcp --dport ${toString data.runner.egress.proxyPort} -j ACCEPT 2>/dev/null; do :; done
    ''}
    while ${iptables} -D nixos-fw -i ${data.runner.tapName} -j DROP 2>/dev/null; do :; done
    while ${ip6tables} -D nixos-fw -i ${data.runner.tapName} -j DROP 2>/dev/null; do :; done
  '';

  installFirewallInputRules = data: ''
    ${iptables} -C nixos-fw -i ${data.runner.tapName} -j DROP 2>/dev/null \
      || ${iptables} -I nixos-fw 1 -i ${data.runner.tapName} -j DROP
    ${iptables} -C nixos-fw -i ${data.runner.tapName} -s ${data.guestAddress} -d ${data.hostAddress} -p tcp --dport ${toString data.runner.forgejoProxyPort} -j ACCEPT 2>/dev/null \
      || ${iptables} -I nixos-fw 1 -i ${data.runner.tapName} -s ${data.guestAddress} -d ${data.hostAddress} -p tcp --dport ${toString data.runner.forgejoProxyPort} -j ACCEPT
    ${lib.optionalString data.runner.egress.enable ''
      ${iptables} -C nixos-fw -i ${data.runner.tapName} -s ${data.guestAddress} -d ${data.hostAddress} -p tcp --dport ${toString data.runner.egress.proxyPort} -j ACCEPT 2>/dev/null \
        || ${iptables} -I nixos-fw 1 -i ${data.runner.tapName} -s ${data.guestAddress} -d ${data.hostAddress} -p tcp --dport ${toString data.runner.egress.proxyPort} -j ACCEPT
    ''}
    ${ip6tables} -C nixos-fw -i ${data.runner.tapName} -j DROP 2>/dev/null \
      || ${ip6tables} -I nixos-fw 1 -i ${data.runner.tapName} -j DROP

    ${iptables} -C nixos-fw -i ${data.runner.tapName} -s ${data.guestAddress} -d ${data.hostAddress} -p tcp --dport ${toString data.runner.forgejoProxyPort} -j ACCEPT
    ${lib.optionalString data.runner.egress.enable ''
      ${iptables} -C nixos-fw -i ${data.runner.tapName} -s ${data.guestAddress} -d ${data.hostAddress} -p tcp --dport ${toString data.runner.egress.proxyPort} -j ACCEPT
    ''}
    ${iptables} -C nixos-fw -i ${data.runner.tapName} -j DROP
    ${ip6tables} -C nixos-fw -i ${data.runner.tapName} -j DROP
  '';

  mkTapDropChainRules = command: chain: ''
    ${command} -n -L ${chain} >/dev/null 2>&1 || ${command} -N ${chain}
    ${lib.concatMapStringsSep "\n" (data: ''
      ${command} -C ${chain} -i ${data.runner.tapName} -j DROP 2>/dev/null \
        || ${command} -A ${chain} -i ${data.runner.tapName} -j DROP
    '') runnerData}
    ${lib.concatMapStringsSep "\n" (data: ''
      ${command} -C ${chain} -i ${data.runner.tapName} -j DROP
    '') runnerData}
  '';

  mkForwardChainRules = command: ''
    ${mkTapDropChainRules command forwardChain}

    ${command} -I FORWARD 1 -j ${forwardChain}
    for duplicateLine in $(${command} -L FORWARD --line-numbers -n | ${pkgs.gawk}/bin/awk -v chain=${lib.escapeShellArg forwardChain} '$1 != "1" && $2 == chain { print $1 }' | ${pkgs.coreutils}/bin/sort -rn); do
      ${command} -D FORWARD "$duplicateLine"
    done

    test "$(${command} -L FORWARD --line-numbers -n | ${pkgs.gawk}/bin/awk '$1 == "1" { print $2; exit }')" = ${lib.escapeShellArg forwardChain}
    ${command} -C FORWARD -j ${forwardChain}
  '';

  mkDockerUserChainRules = command: ''
    if ${command} -n -L DOCKER-USER >/dev/null 2>&1; then
      ${mkTapDropChainRules command dockerUserChain}

      while ${command} -D DOCKER-USER -j ${dockerUserChain} 2>/dev/null; do :; done
      ${command} -I DOCKER-USER 1 -j ${dockerUserChain}

      test "$(${command} -L DOCKER-USER --line-numbers -n | ${pkgs.gawk}/bin/awk '$1 == "1" { print $2; exit }')" = ${lib.escapeShellArg dockerUserChain}
      ${command} -C DOCKER-USER -j ${dockerUserChain}
    fi
  '';

  removeDockerUserChainRules = command: ''
    if ${command} -n -L ${dockerUserChain} >/dev/null 2>&1; then
      if ${command} -n -L DOCKER-USER >/dev/null 2>&1; then
        while ${command} -D DOCKER-USER -j ${dockerUserChain} 2>/dev/null; do :; done
      fi
      ${command} -F ${dockerUserChain}
      ${command} -X ${dockerUserChain}
    fi
  '';

  firewallGuardUnit = "forgejo-runner-firewall-guard.service";
  firewallGuardBoundUnits = lib.concatMap (data: [
    "microvm@${data.vmName}.service"
    "microvm-tap-interfaces@${data.vmName}.service"
  ]) runnerData;
  firewallGuardScript = pkgs.writeShellScript "forgejo-runner-firewall-guard" ''
    set -euo pipefail
    mkdir -p /run/lock
    exec 9>/run/lock/forgejo-runner-firewall.lock
    ${pkgs.util-linux}/bin/flock 9
    failClosed() {
      ${pkgs.systemd}/bin/systemctl stop ${lib.escapeShellArgs firewallGuardBoundUnits} || true
    }
    trap failClosed ERR
    ${mkForwardChainRules iptables}
    ${mkForwardChainRules ip6tables}
    ${mkDockerUserChainRules iptables}
    ${mkDockerUserChainRules ip6tables}
    ${lib.concatMapStringsSep "\n" installFirewallInputRules runnerData}
    ${lib.concatMapStringsSep "\n" (data: ''
      while ${iptables} -D FORWARD -i ${data.runner.tapName} -j DROP 2>/dev/null; do :; done
      while ${ip6tables} -D FORWARD -i ${data.runner.tapName} -j DROP 2>/dev/null; do :; done
    '') runnerData}
    trap - ERR
  '';
  firewallCleanupScript = pkgs.writeShellScript "forgejo-runner-firewall-cleanup" ''
    set -euo pipefail
    mkdir -p /run/lock
    exec 9>/run/lock/forgejo-runner-firewall.lock
    ${pkgs.util-linux}/bin/flock 9
    ${lib.concatMapStringsSep "\n" (data: ''
      ${iptables} -I FORWARD 1 -i ${data.runner.tapName} -j DROP
      ${ip6tables} -I FORWARD 1 -i ${data.runner.tapName} -j DROP
      ${iptables} -C FORWARD -i ${data.runner.tapName} -j DROP
      ${ip6tables} -C FORWARD -i ${data.runner.tapName} -j DROP
    '') runnerData}
    ${lib.concatMapStringsSep "\n" removeFirewallInputRules runnerData}
    ${removeDockerUserChainRules iptables}
    ${removeDockerUserChainRules ip6tables}
    while ${iptables} -D FORWARD -j ${forwardChain} 2>/dev/null; do :; done
    while ${ip6tables} -D FORWARD -j ${forwardChain} 2>/dev/null; do :; done
    if ${iptables} -n -L ${forwardChain} >/dev/null 2>&1; then
      ${iptables} -F ${forwardChain}
      ${iptables} -X ${forwardChain}
    fi
    if ${ip6tables} -n -L ${forwardChain} >/dev/null 2>&1; then
      ${ip6tables} -F ${forwardChain}
      ${ip6tables} -X ${forwardChain}
    fi
  '';

  mkVolumeScript =
    volume:
    let
      bytes = volume.sizeMiB * 1024 * 1024;
      image = lib.escapeShellArg volume.image;
      label = lib.escapeShellArg volume.label;
      recoveryInterlock = volume.recoveryInterlock or null;
      migrationInterlock = volume.migrationInterlock or null;
      temporaryTemplate = lib.escapeShellArg "${volume.subvolume}/.${volume.fileName}.XXXXXX";
      subvolume = lib.escapeShellArg volume.subvolume;
    in
    ''
      ${lib.optionalString (recoveryInterlock != null) ''
        if [ -e ${lib.escapeShellArg recoveryInterlock} ] || [ -L ${lib.escapeShellArg recoveryInterlock} ]; then
          if [ ! -e ${image} ] && [ ! -L ${image} ]; then
            echo "Refusing to create missing Docker storage while the recovery interlock is armed" >&2
            exit 1
          fi
        fi
      ''}
      for staleImage in ${subvolume}/.${volume.fileName}.??????; do
        [ -e "$staleImage" ] || [ -L "$staleImage" ] || continue
        case "$staleImage" in
          ${subvolume}/.${volume.fileName}.[[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]]) ;;
          *) exit 1 ;;
        esac
        test -f "$staleImage"
        test ! -L "$staleImage"
        test "$(stat -c %u "$staleImage")" -eq 0
        test "$(stat -c %h "$staleImage")" -eq 1
        rm -f -- "$staleImage"
      done
      if [ -e ${image} ] || [ -L ${image} ]; then
        test -f ${image}
        test ! -L ${image}
        if [ "$(stat -c %s ${image})" -ne ${toString bytes} ]; then
          ${lib.optionalString (migrationInterlock != null) ''
            if [ -e ${lib.escapeShellArg migrationInterlock} ] || [ -L ${lib.escapeShellArg migrationInterlock} ]; then
              test -d ${lib.escapeShellArg migrationInterlock}
              test ! -L ${lib.escapeShellArg migrationInterlock}
            else
              install -d -m 0700 ${lib.escapeShellArg migrationInterlock}
            fi
            printf '%s\n' "${volume.fileName} has the wrong size; owner migration is required" >${lib.escapeShellArg migrationInterlock}/reason
            chmod 0600 ${lib.escapeShellArg migrationInterlock}/reason
          ''}
          ${lib.optionalString (migrationInterlock == null) ''
            echo "Refusing storage image with unexpected size: ${volume.fileName}" >&2
            exit 1
          ''}
        fi
      else
        test "$(df --output=avail -B1 /var | tail -n 1 | tr -d ' ')" -ge ${toString bytes}
        temporaryImage="$(mktemp ${temporaryTemplate})"
        trap 'rm -f "$temporaryImage"' EXIT
        chattr +C "$temporaryImage"
        fallocate -l ${toString volume.sizeMiB}M "$temporaryImage"
        mkfs.ext4 -F -L ${label} "$temporaryImage"
        test "$(stat -c %s "$temporaryImage")" -eq ${toString bytes}
        case "$(lsattr -d "$temporaryImage")" in *C*) ;; *) exit 1 ;; esac
        test "$(blkid -s TYPE -o value "$temporaryImage")" = ext4
        test "$(blkid -s LABEL -o value "$temporaryImage")" = ${label}
        mv "$temporaryImage" ${image}
        trap - EXIT
      fi
      test -f ${image}
      test ! -L ${image}
      if [ "$(stat -c %s ${image})" -eq ${toString bytes} ]; then
        case "$(lsattr -d ${image})" in *C*) ;; *) exit 1 ;; esac
      else
        ${lib.optionalString (migrationInterlock == null) ''
          echo "Refusing storage image with unexpected size: ${volume.fileName}" >&2
          exit 1
        ''}
        ${lib.optionalString (migrationInterlock != null) ":"}
      fi
      test "$(blkid -s TYPE -o value ${image})" = ext4
      test "$(blkid -s LABEL -o value ${image})" = ${label}
      chown microvm:kvm ${image}
      chmod 0600 ${image}
    '';

  mkVolumes =
    data:
    let
      resources = data.runner.resources;
      addQgroupReserve =
        volume:
        volume
        // {
          qgroupReserveMiB = lib.max resources.qgroupReserveMinMiB (
            builtins.div (volume.sizeMiB * resources.qgroupReservePercent + 99) 100
          );
        };
    in
    map addQgroupReserve [
      {
        subvolume = data.stateSubvolume;
        image = data.stateImage;
        fileName = "var.raw";
        label = "forgejo-run-var";
        mountPoint = "/var";
        sizeMiB = resources.runnerStateMiB;
      }
      {
        subvolume = data.nixCacheSubvolume;
        image = data.nixCacheImage;
        fileName = "nix-cache.raw";
        label = "fj-run-nix";
        mountPoint = "/var/lib/forgejo-nix";
        sizeMiB = resources.nixCacheMiB;
        migrationInterlock = data.nixCacheMigrationInterlock;
      }
      {
        subvolume = data.dockerSubvolume;
        image = data.dockerImage;
        fileName = "docker.raw";
        label = "fj-run-docker";
        mountPoint = "/var/lib/docker";
        sizeMiB = resources.dockerMiB;
        inherit (data) recoveryInterlock;
      }
      {
        subvolume = data.workSubvolume;
        image = data.workImage;
        fileName = "work.raw";
        label = "fj-run-work";
        mountPoint = "/var/lib/forgejo-runner-work";
        sizeMiB = resources.workMiB;
      }
    ];

  qgroupLimitTotalMiB =
    data:
    lib.foldl' (total: volume: total + volume.sizeMiB + volume.qgroupReserveMiB) 0 (mkVolumes data);

  mkGuest =
    data:
    {
      hostConfig,
      pkgs,
      ...
    }:
    let
      runnerService = "gitea-runner-${data.name}";
      runnerUnit = "${runnerService}.service";
      imageUnit = "forgejo-runner-images-${data.name}.service";
      runnerTarget = "forgejo-runner-stack-${data.name}";
      runnerTargetUnit = "${runnerTarget}.target";
      tokenService = "forgejo-runner-token-${data.name}";
      tokenUnit = "${tokenService}.service";
      dockerResetService = "forgejo-runner-docker-reset-${data.name}";
      dockerResetUnit = "${dockerResetService}.service";
      tokenRuntimeDir = "forgejo-runner-${data.name}";
      tokenFile = "/run/${tokenRuntimeDir}/token.env";
      egressProxy = "http://${data.hostAddress}:${toString data.runner.egress.proxyPort}";
      noProxy = "127.0.0.1,localhost,${data.hostAddress},${data.guestAddress}";
      proxyEnvironment = lib.optionalAttrs data.runner.egress.enable {
        HTTP_PROXY = egressProxy;
        HTTPS_PROXY = egressProxy;
        NO_PROXY = noProxy;
        http_proxy = egressProxy;
        https_proxy = egressProxy;
        no_proxy = noProxy;
      };
      runnerEnvironment = proxyEnvironment;
      nixVolumeService = "forgejo-runner-nix-volume-${data.name}";
      nixVolumeUnit = "${nixVolumeService}.service";
      nixVolumePath = "/var/lib/forgejo-nix";
      nixVolumeData = "${nixVolumePath}/volume";
      cacheMinFreeBytes = runnerCfg.nixCacheMinFreeMiB * 1024 * 1024;
      cacheMaxFreeBytes = runnerCfg.nixCacheMaxFreeMiB * 1024 * 1024;
      jobContainerOptions = lib.concatStringsSep " " [
        "--security-opt=no-new-privileges"
        "--mount type=volume,src=forgejo-nix,dst=/nix"
      ];
      nixVolumeScript = pkgs.writeShellScript "${nixVolumeService}" ''
        set -euo pipefail
        ${pkgs.util-linux}/bin/mountpoint --quiet ${nixVolumePath}
        test "$(${pkgs.util-linux}/bin/findmnt -n -o FSTYPE --target ${nixVolumePath})" = ext4
        test -d ${nixVolumePath}
        test ! -L ${nixVolumePath}
        ${pkgs.coreutils}/bin/install -d -m 0755 ${nixVolumeData}
        epochFile=${nixVolumeData}/.forgejo-nix-seed-epoch
        if [ -e "$epochFile" ] || [ -L "$epochFile" ]; then
          test -f "$epochFile"
          test ! -L "$epochFile"
          test "$(< "$epochFile")" = ${lib.escapeShellArg data.runner.runner.nixSeedEpoch}
        else
          test -z "$(${pkgs.findutils}/bin/find ${nixVolumeData} -mindepth 1 -maxdepth 1 -print -quit)"
        fi
        if ! ${pkgs.docker}/bin/docker volume inspect forgejo-nix >/dev/null 2>&1; then
          ${pkgs.docker}/bin/docker volume create --driver local --opt type=none --opt o=bind --opt device=/var/lib/forgejo-nix/volume forgejo-nix >/dev/null
        fi
        test "$(${pkgs.docker}/bin/docker volume inspect --format '{{.Driver}}' forgejo-nix)" = local
        test "$(${pkgs.docker}/bin/docker volume inspect --format '{{.Options.type}}' forgejo-nix)" = none
        test "$(${pkgs.docker}/bin/docker volume inspect --format '{{.Options.o}}' forgejo-nix)" = bind
        test "$(${pkgs.docker}/bin/docker volume inspect --format '{{.Options.device}}' forgejo-nix)" = /var/lib/forgejo-nix/volume
      '';
      admissionScript = pkgs.writeShellScript "forgejo-runner-admission-${data.name}" ''
        set -euo pipefail
        echo "Runner admission: validating dynamic state and workspace"
        runnerState=/var/lib/gitea-runner
        test -L "$runnerState"
        resolvedRunnerState="$(${pkgs.coreutils}/bin/readlink --canonicalize-existing -- "$runnerState")"
        test "$resolvedRunnerState" = /var/lib/private/gitea-runner
        test -d "$resolvedRunnerState"
        test ! -L "$resolvedRunnerState"
        test -d /var/lib/forgejo-runner-work
        test ! -L /var/lib/forgejo-runner-work
        ${pkgs.util-linux}/bin/mountpoint --quiet /var/lib/forgejo-runner-work
        ${pkgs.coreutils}/bin/chown --reference="$resolvedRunnerState" /var/lib/forgejo-runner-work
        ${pkgs.coreutils}/bin/chmod 0700 /var/lib/forgejo-runner-work
        echo "Runner admission: cleaning disposable workspace state"
        test -z "$(${pkgs.docker}/bin/docker ps --quiet)"
        ${pkgs.findutils}/bin/find /var/lib/forgejo-runner-work -mindepth 1 -maxdepth 1 -exec ${pkgs.coreutils}/bin/rm -rf -- {} +
        echo "Runner admission: checking free space"
        test "$(${pkgs.coreutils}/bin/df --output=avail -B1 /var | ${pkgs.coreutils}/bin/tail -n 1 | ${pkgs.coreutils}/bin/tr -d ' ')" -ge 536870912
        test "$(${pkgs.coreutils}/bin/df --output=avail -B1 /var/lib/docker | ${pkgs.coreutils}/bin/tail -n 1 | ${pkgs.coreutils}/bin/tr -d ' ')" -ge 1073741824
        test "$(${pkgs.coreutils}/bin/df --output=avail -B1 /var/lib/forgejo-runner-work | ${pkgs.coreutils}/bin/tail -n 1 | ${pkgs.coreutils}/bin/tr -d ' ')" -ge 536870912
        echo "Runner admission: complete"
      '';
      dockerObserverService = "forgejo-runner-docker-observer-${data.name}";
      dockerObserverUnit = "${dockerObserverService}.service";
      dockerObserverScript = pkgs.writeShellScript "${dockerObserverService}" ''
        set -euo pipefail
        docker=${pkgs.docker}/bin/docker
        jq=${pkgs.jq}/bin/jq
        stat=${pkgs.coreutils}/bin/stat
        storeRoot=${nixVolumeData}/store

        inspect_container() {
          local id="$1" name user state exitCode networkInfo volumeInfo capabilityInfo
          name="$($docker inspect --format '{{.Name}}' "$id" 2>/dev/null || true)"
          [ -n "$name" ] || return 0
          user="$($docker inspect --format '{{.Config.User}}' "$id" 2>/dev/null || true)"
          state="$($docker inspect --format '{{.State.Status}}' "$id" 2>/dev/null || true)"
          exitCode="$($docker inspect --format '{{.State.ExitCode}}' "$id" 2>/dev/null || true)"
          networkInfo="$($docker inspect --format '{{range $network, $endpoint := .NetworkSettings.Networks}}network={{$network}} ip={{$endpoint.IPAddress}} aliases={{json $endpoint.Aliases}} {{end}}' "$id" 2>/dev/null || true)"
          volumeInfo="$($docker inspect --format '{{range .Mounts}}{{if eq .Name "forgejo-nix"}}volume={{.Name}} destination={{.Destination}} rw={{.RW}}{{end}}{{end}}' "$id" 2>/dev/null || true)"
          capabilityInfo="$($docker inspect --format 'cap-add={{json .HostConfig.CapAdd}} cap-drop={{json .HostConfig.CapDrop}}' "$id" 2>/dev/null || true)"
          echo "Docker observer: id=$id name=$name user=$user state=$state exit=$exitCode $networkInfo $volumeInfo $capabilityInfo"
          if [ -n "$volumeInfo" ]; then
            echo "Docker observer: persistent store metadata"
            for path in "$storeRoot" "$storeRoot"/tmp-* "$storeRoot"/tmp-*/*; do
              [ -e "$path" ] || continue
              $stat -c 'path=%n uid=%u gid=%g mode=%a type=%F' -- "$path"
            done
          fi
        }

        observe_active_store_tmp() {
          local lastSnapshot="" path snapshot
          while true; do
            snapshot="$(for path in "$storeRoot"/tmp-* "$storeRoot"/tmp-*/*; do
              [ -e "$path" ] || continue
              $stat -c 'path=%n uid=%u gid=%g mode=%a type=%F' -- "$path"
            done)"
            if [ -n "$snapshot" ] && [ "$snapshot" != "$lastSnapshot" ]; then
              echo "Docker observer: active persistent store temporary metadata"
              printf '%s\n' "$snapshot"
            fi
            lastSnapshot="$snapshot"
            sleep 2
          done
        }

        echo "Docker observer: security-options=$($docker info --format '{{json .SecurityOptions}}')"
        observe_active_store_tmp &
        storeTmpObserverPid=$!
        trap 'kill "$storeTmpObserverPid" 2>/dev/null || true' EXIT
        while true; do
          echo "Docker observer: event stream starting"
          set +e
          coproc dockerEvents {
            $docker events --filter type=container --format '{{json .}}'
          }
          eventStreamPid="''${dockerEvents_PID}"
          while IFS= read -r event <&"''${dockerEvents[0]}"; do
            eventFields="$(printf '%s' "$event" | $jq --raw-output '[.Action // .status // empty, .id // .Actor.ID // empty] | @tsv' 2>/dev/null)"
            parserStatus=$?
            if [ "$parserStatus" -ne 0 ]; then
              echo "Docker observer: ignored unparseable container event" >&2
              continue
            fi
            IFS=$'\t' read -r action id <<<"$eventFields"
            case "$action" in
              create|start|die|destroy)
                if [ -n "$id" ]; then
                  inspect_container "$id"
                else
                  echo "Docker observer: ignored container event without ID" >&2
                fi
                ;;
            esac
          done
          if wait "$eventStreamPid"; then
            eventStatus=0
          else
            eventStatus=$?
          fi
          set -e
          echo "Docker observer: event stream ended status=$eventStatus; retrying" >&2
          sleep 1
        done
      '';
      dockerResetScript = pkgs.writeShellScript "${dockerResetService}" ''
        set -euo pipefail
        dockerData=/var/lib/docker
        ${pkgs.util-linux}/bin/mountpoint --quiet "$dockerData"
        test "$(${pkgs.util-linux}/bin/findmnt -n -o FSTYPE --target "$dockerData")" = ext4
        test -d "$dockerData"
        test ! -L "$dockerData"
        if ${pkgs.systemd}/bin/systemctl is-active --quiet docker.service; then
          echo "Refusing cold Docker reset while Docker is active" >&2
          exit 1
        fi
        ${pkgs.findutils}/bin/find "$dockerData" -mindepth 1 -maxdepth 1 -exec ${pkgs.coreutils}/bin/rm -rf -- {} +
        test -z "$(${pkgs.findutils}/bin/find "$dockerData" -mindepth 1 -maxdepth 1 -print -quit)"
      '';
    in
    {
      microvm = {
        hypervisor = "qemu";
        storeOnDisk = true;
        storeDiskType = "erofs";
        registerClosure = false;
        mem = data.runner.resources.memoryMiB;
        vcpu = data.runner.resources.vcpus;
        shares = [ ];
        credentialFiles.FORGEJO_RUNNER_TOKEN =
          hostConfig.sops.secrets.${data.runner.runner.tokenSecret}.path;
        interfaces = [
          {
            type = "tap";
            id = data.runner.tapName;
            mac = data.runner.macAddress;
          }
        ];
        volumes = map (volume: {
          inherit (volume) image label mountPoint;
          size = volume.sizeMiB;
          fsType = "ext4";
          autoCreate = false;
        }) (mkVolumes data);
        binScripts.tap-up = lib.mkAfter ''
          ${pkgs.iproute2}/bin/ip address replace ${data.hostAddress}/30 dev ${data.runner.tapName}
          echo 1 > /proc/sys/net/ipv6/conf/${data.runner.tapName}/disable_ipv6
        '';
      };

      networking = {
        hostName = data.vmName;
        enableIPv6 = false;
        nameservers = [ ];
        defaultGateway = null;
        defaultGateway6 = null;
        useDHCP = false;
        useNetworkd = true;
      };

      nix = {
        nrBuildUsers = lib.max 8 (data.runner.resources.vcpus * 2);
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          sandbox = true;
          sandbox-fallback = false;
          build-users-group = "nixbld";
          substituters = [ "https://cache.nixos.org/" ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          ];
          max-jobs = data.runner.resources.vcpus;
          min-free = cacheMinFreeBytes;
          max-free = cacheMaxFreeBytes;
          min-free-check-interval = 5;
          auto-optimise-store = false;
        };
      };
      users = {
        mutableUsers = false;
        allowNoPasswordLogin = true;
        users.root.hashedPassword = "!";
      };
      environment.systemPackages = with pkgs; [
        bashInteractive
        cacert
        coreutils
        findutils
        gitMinimal
        gnugrep
        gnused
        gnutar
        gzip
        nix
        which
        xz
      ];

      virtualisation.docker = {
        enable = true;
        daemon.settings = {
          "bip" = "172.30.0.1/24";
          "ipv6" = false;
          "log-driver" = "local";
          "userland-proxy" = false;
        }
        // lib.optionalAttrs data.runner.egress.enable {
          "proxies" = {
            "http-proxy" = egressProxy;
            "https-proxy" = egressProxy;
            "no-proxy" = noProxy;
          };
        };
      };

      services.gitea-actions-runner = {
        package = pkgs.forgejo-runner;
        instances.${data.name} = {
          enable = true;
          name = data.runner.runner.name;
          url = "http://${data.hostAddress}:${toString data.runner.forgejoProxyPort}";
          inherit tokenFile;
          labels = data.runner.runner.labels;
          settings = {
            runner = {
              capacity = data.runner.runner.capacity;
              timeout = "3h";
              shutdown_timeout = "5m";
              envs = runnerEnvironment;
            };
            cache.enabled = false;
            container = {
              enable_ipv6 = false;
              privileged = false;
              options = jobContainerOptions;
              valid_volumes = [ "forgejo-nix" ];
              docker_host = "-";
              force_pull = false;
              workdir_parent = "/var/lib/forgejo-runner-work";
            };
          };
        };
      };

      systemd = {
        network.networks."10-forgejo-runner" = {
          matchConfig.MACAddress = data.runner.macAddress;
          address = [ "${data.guestAddress}/30" ];
          networkConfig = {
            ConfigureWithoutCarrier = true;
            DHCP = "no";
            IPv6AcceptRA = false;
            LinkLocalAddressing = "no";
          };
        };

        targets.${runnerTarget} = {
          description = "Forgejo runner stack for ${data.name}";
          requires = [
            tokenUnit
            imageUnit
            runnerUnit
          ];
          after = [
            "docker.service"
            tokenUnit
            imageUnit
          ];
          partOf = [ "docker.service" ];
        };

        services = {
          docker.wants = [ runnerTargetUnit ];

          "${dockerResetService}" = {
            description = "Reset disposable Docker data before cold start";
            requiredBy = [ "docker.service" ];
            before = [ "docker.service" ];
            after = [ "local-fs.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              RefuseManualStart = true;
              ExecStart = dockerResetScript;
              StandardOutput = "journal+console";
              StandardError = "journal+console";
            };
          };

          "${nixVolumeService}" = {
            description = "Create the persistent Docker Nix volume";
            requires = [ "docker.service" ];
            after = [ "docker.service" ];
            before = [ imageUnit ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = nixVolumeScript;
              StandardOutput = "journal+console";
              StandardError = "journal+console";
            };
          };

          "${dockerObserverService}" = {
            description = "Observe Forgejo runner Docker job and service topology";
            wantedBy = [ runnerTargetUnit ];
            requires = [
              "docker.service"
              nixVolumeUnit
            ];
            after = [
              "docker.service"
              nixVolumeUnit
            ];
            before = [ runnerUnit ];
            partOf = [
              runnerTargetUnit
              "docker.service"
            ];
            serviceConfig = {
              Type = "simple";
              Restart = "always";
              RestartSec = "1s";
              ExecStart = dockerObserverScript;
              StandardOutput = "journal+console";
              StandardError = "journal+console";
            };
          };

          "${runnerService}" = {
            requires = [
              tokenUnit
              imageUnit
              nixVolumeUnit
            ];
            wants = [ dockerObserverUnit ];
            after = [
              dockerObserverUnit
              tokenUnit
              imageUnit
              nixVolumeUnit
            ];
            partOf = [ runnerTargetUnit ];
            environment = proxyEnvironment // {
              PATH = lib.mkForce "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
            };
            serviceConfig = {
              ExecStartPre = lib.mkBefore [ "+${admissionScript}" ];
              StandardOutput = "journal+console";
              StandardError = "journal+console";
            };
          };

          "${tokenService}" = {
            description = "Prepare runtime token for Forgejo runner ${data.name}";
            before = [ runnerUnit ];
            requiredBy = [ runnerUnit ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              RuntimeDirectory = tokenRuntimeDir;
              RuntimeDirectoryMode = "0700";
              RuntimeDirectoryPreserve = true;
              StandardOutput = "journal+console";
              StandardError = "journal+console";
            };
            script = ''
              set -euo pipefail
              credential=/run/credentials/@system/FORGEJO_RUNNER_TOKEN
              test -s "$credential"
              token="$(${pkgs.coreutils}/bin/cat -- "$credential")"
              test -n "$token"
              temporary="$(${pkgs.coreutils}/bin/mktemp "/run/${tokenRuntimeDir}/.token.env.XXXXXX")"
              trap '${pkgs.coreutils}/bin/rm -f -- "$temporary"' EXIT
              ${pkgs.coreutils}/bin/printf 'TOKEN=%s\n' "$token" >"$temporary"
              ${pkgs.coreutils}/bin/chmod 0400 "$temporary"
              ${pkgs.coreutils}/bin/mv -f -- "$temporary" ${tokenFile}
              trap - EXIT
              echo "Prepared runtime token for Forgejo runner ${data.name}"
            '';
          };

          "forgejo-runner-images-${data.name}" = {
            description = "Load offline OCI images for ${data.name}";
            requires = [
              "docker.service"
              dockerResetUnit
              nixVolumeUnit
            ];
            after = [
              "docker.service"
              dockerResetUnit
              nixVolumeUnit
            ];
            partOf = [ runnerTargetUnit ];
            before = [ runnerUnit ];
            requiredBy = [ runnerUnit ];
            path = [
              pkgs.docker
              pkgs.gzip
            ];
            serviceConfig = {
              Type = "oneshot";
              TimeoutStartSec = "15min";
              StandardOutput = "journal+console";
              StandardError = "journal+console";
            };
            script = ''
              set -euo pipefail

              inspect_image_id() {
                ${pkgs.coreutils}/bin/timeout --foreground --signal=TERM --kill-after=5s 30s \
                  docker image inspect --format '{{.Id}}' "$1"
              }

              validate_archive() {
                local archive="$1"
                local reference="$2"
                local config
                local config_digest

                test -r "$archive"
                config="$(
                  ${pkgs.coreutils}/bin/timeout --foreground --signal=TERM --kill-after=5s 30s \
                    ${pkgs.gnutar}/bin/tar -xOf "$archive" manifest.json \
                    | ${pkgs.jq}/bin/jq --exit-status --raw-output --arg reference "$reference" '
                        map(select((.RepoTags // []) | index($reference)))
                        | if length == 1 then .[0].Config else error("expected one matching image") end
                      '
                )"
                if ! ${pkgs.gnugrep}/bin/grep --quiet --extended-regexp '^[0-9a-f]{64}\.json$' <<<"$config"; then
                  echo "Invalid image config in offline archive for $reference: $config" >&2
                  return 1
                fi
                config_digest="$(
                  ${pkgs.coreutils}/bin/timeout --foreground --signal=TERM --kill-after=5s 30s \
                    ${pkgs.gnutar}/bin/tar -xOf "$archive" "$config" \
                    | ${pkgs.coreutils}/bin/sha256sum \
                    | ${pkgs.coreutils}/bin/cut -d ' ' -f 1
                )"
                if [ "$config" != "$config_digest.json" ]; then
                  echo "Invalid config digest in offline archive for $reference" >&2
                  return 1
                fi
              }

              ${lib.concatMapStringsSep "\n" (image: ''
                echo "Validating immutable offline archive ${image.reference}"
                validate_archive ${lib.escapeShellArg image.archive} ${lib.escapeShellArg image.reference}
              '') data.images}

              echo "Refusing disposable Docker cleanup while containers are active"
              test -z "$(docker ps --quiet)"
              mapfile -t all_containers < <(docker ps --all --quiet)
              if [ "''${#all_containers[@]}" -gt 0 ]; then
                ${pkgs.coreutils}/bin/timeout --foreground --signal=TERM --kill-after=5s 2m \
                  docker container rm --force "''${all_containers[@]}" >/dev/null
              fi
              ${pkgs.coreutils}/bin/timeout --foreground --signal=TERM --kill-after=30s 2m \
                docker builder prune --all --force >/dev/null
              mapfile -t all_images < <(docker image ls --all --quiet --no-trunc | ${pkgs.coreutils}/bin/sort --unique)
              if [ "''${#all_images[@]}" -gt 0 ]; then
                ${pkgs.coreutils}/bin/timeout --foreground --signal=TERM --kill-after=5s 2m \
                  docker image rm --force "''${all_images[@]}" >/dev/null
              fi
              ${pkgs.coreutils}/bin/timeout --foreground --signal=TERM --kill-after=5s 2m \
                docker network prune --force >/dev/null
              test -z "$(docker ps --all --quiet)"
              test -z "$(docker image ls --all --quiet)"
              test "$(docker volume ls --quiet)" = forgejo-nix
              ${lib.concatMapStringsSep "\n" (image: ''
                echo "Loading offline image ${image.reference}"
                if ! ${pkgs.coreutils}/bin/timeout --foreground --signal=TERM --kill-after=30s 5m \
                  docker load --input ${image.archive}; then
                  echo "Offline image import failed or timed out: ${image.reference}" >&2
                  exit 1
                fi
              '') data.images}

              ${lib.concatMapStringsSep "\n" (image: ''
                echo "Verifying loaded image ${image.reference}"
                if ! actual_image_id="$(inspect_image_id ${lib.escapeShellArg image.reference})"; then
                  echo "Docker image verification failed or timed out: ${image.reference}" >&2
                  exit 1
                fi
                if ! ${pkgs.gnugrep}/bin/grep --quiet --extended-regexp '^sha256:[0-9a-f]{64}$' <<<"$actual_image_id"; then
                  echo "Docker returned an invalid image ID for ${image.reference}: $actual_image_id" >&2
                  exit 1
                fi
                echo "Verified loaded image ${image.reference} as $actual_image_id from its immutable Nix store archive"
              '') data.images}
              test "$(docker volume ls --quiet)" = forgejo-nix
              echo "Finished loading and verifying offline images for ${data.name}"
            '';
          };

          forgejo-runner-health = {
            serviceConfig = {
              Type = "oneshot";
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
            };
            script = ''
              ${pkgs.curl}/bin/curl --fail --silent --show-error --connect-timeout 5 http://${data.hostAddress}:${toString data.runner.forgejoProxyPort}/api/healthz >/dev/null
            '';
          };
        };

        timers.forgejo-runner-health = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "5min";
            Unit = "forgejo-runner-health.service";
          };
        };

      };
    };

  storageServices = lib.mapAttrs' (
    name: data:
    lib.nameValuePair data.storageService {
      description = "Provision isolated storage for Forgejo runner ${name}";
      before = [
        "install-microvm-${data.vmName}.service"
        "microvm-tap-interfaces@${data.vmName}.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        pkgs.btrfs-progs
        pkgs.coreutils
        pkgs.e2fsprogs
        pkgs.util-linux
      ];
      script =
        let
          volumes = mkVolumes data;
          storageDir = lib.escapeShellArg data.storageDir;
        in
        ''
          set -euo pipefail
          exec 9>/run/lock/forgejo-runner-storage.lock
          flock 9
          test "$(findmnt -n -o FSTYPE --target /var)" = btrfs
          if [ ! -e ${storageDir} ]; then
            install -d -m 0755 /var/lib/microvms
            btrfs subvolume create ${storageDir}
          fi
          test -d ${storageDir}
          test ! -L ${storageDir}
          btrfs subvolume show ${storageDir} >/dev/null
          btrfs quota enable /var
          ${lib.concatMapStringsSep "\n" (
            volume:
            let
              subvolume = lib.escapeShellArg volume.subvolume;
            in
            ''
              if [ ! -e ${subvolume} ]; then
                ${lib.optionalString ((volume.recoveryInterlock or null) != null) ''
                  if [ -e ${lib.escapeShellArg volume.recoveryInterlock} ] || [ -L ${lib.escapeShellArg volume.recoveryInterlock} ]; then
                    echo "Refusing to create missing Docker subvolume while the recovery interlock is armed" >&2
                    exit 1
                  fi
                ''}
                btrfs subvolume create ${subvolume}
              fi
              test -d ${subvolume}
              test ! -L ${subvolume}
              btrfs subvolume show ${subvolume} >/dev/null
              btrfs qgroup limit ${toString (volume.sizeMiB + volume.qgroupReserveMiB)}M ${subvolume}
            ''
          ) volumes}
          ${lib.concatMapStringsSep "\n" mkVolumeScript volumes}
          qgroupReport="$(btrfs qgroup show -re --raw --sync /var 2>&1)"
          if printf '%s\n' "$qgroupReport" | ${pkgs.gnugrep}/bin/grep -qi 'inconsistent'; then
            printf '%s\n' "$qgroupReport" >&2
            echo "Refusing runner storage admission: Btrfs qgroup accounting is inconsistent" >&2
            exit 1
          fi
          ${lib.concatMapStringsSep "\n" (
            volume:
            let
              subvolume = lib.escapeShellArg volume.subvolume;
              limitBytes = (volume.sizeMiB + volume.qgroupReserveMiB) * 1024 * 1024;
              reserveFloorBytes = builtins.div (
                volume.qgroupReserveMiB * data.runner.resources.qgroupReserveFloorPercent * 1024 * 1024
              ) 100;
            in
            ''
              qgroupId="0/$(btrfs inspect-internal rootid ${subvolume})"
              read -r referenced exclusive maxReferenced maxExclusive < <(
                printf '%s\n' "$qgroupReport" \
                  | ${pkgs.gawk}/bin/awk -v id="$qgroupId" '$1 == id { print $2, $3, $4, $5; found=1 } END { if (!found) exit 1 }'
              )
              test "$maxReferenced" -eq ${toString limitBytes}
              remaining=$((maxReferenced - referenced))
              printf '%s: qgroup=%s referenced=%s exclusive=%s max-referenced=%s max-exclusive=%s remaining=%s reserve-floor=%s\n' \
                ${subvolume} "$qgroupId" "$referenced" "$exclusive" "$maxReferenced" "$maxExclusive" "$remaining" ${toString reserveFloorBytes}
              if [ "$remaining" -lt ${toString reserveFloorBytes} ]; then
                echo "Refusing runner storage admission: Btrfs qgroup reserve is nearly exhausted for ${volume.subvolume}" >&2
                exit 1
              fi
            ''
          ) volumes}
        '';
    }
  ) runners;

  openHandleProbe = pkgs.writeShellScript "forgejo-runner-open-handle-probe" ''
    set -u

    if [ "$#" -ne 2 ]; then
      echo "Usage: $0 IMAGE PROC_ROOT" >&2
      exit 2
    fi

    image="$1"
    procRoot="$2"
    if ! ${pkgs.coreutils}/bin/stat -Lc '%d:%i' -- "$image" >/dev/null; then
      echo "Open-handle probe could not inspect $image" >&2
      exit 2
    fi
    if [ ! -d "$procRoot" ] || [ -L "$procRoot" ]; then
      echo "Open-handle probe cannot traverse $procRoot" >&2
      exit 2
    fi

    shopt -s nullglob
    procDirectories=("$procRoot"/[0-9]*)
    if (( ''${#procDirectories[@]} == 0 )); then
      echo "Open-handle probe found no process directories in $procRoot" >&2
      exit 2
    fi

    fdDirectories=()
    for procDirectory in "''${procDirectories[@]}"; do
      if [ ! -d "$procDirectory" ]; then
        continue
      fi
      fdDirectory="$procDirectory/fd"
      if [ ! -d "$fdDirectory" ] || [ -L "$fdDirectory" ]; then
        if [ -d "$procDirectory" ]; then
          echo "Open-handle probe cannot traverse $fdDirectory" >&2
          exit 2
        fi
        continue
      fi
      fdDirectories+=("$fdDirectory")
    done
    if (( ''${#fdDirectories[@]} == 0 )); then
      echo "Open-handle probe could not enumerate any descriptor directories" >&2
      exit 2
    fi

    descriptorScanStatus=0
    openDescriptors="$(
      ${pkgs.findutils}/bin/find -L "''${fdDirectories[@]}" -mindepth 1 -maxdepth 1 -samefile "$image" -print
    )" || descriptorScanStatus=$?
    if [ "$descriptorScanStatus" -ne 0 ]; then
      echo "Open-handle descriptor enumeration failed with status $descriptorScanStatus" >&2
      exit 2
    fi
    if [ -n "$openDescriptors" ]; then
      printf 'Open descriptors for %s:\n%s\n' "$image" "$openDescriptors" >&2
      exit 1
    fi
  '';

  cacheResetServices = lib.mapAttrs' (
    name: data:
    lib.nameValuePair "forgejo-runner-nix-cache-reset-${name}" (
      let
        cacheVolume = lib.findFirst (
          volume: volume.fileName == "nix-cache.raw"
        ) (throw "missing Nix cache volume") (mkVolumes data);
        cacheResetScript = pkgs.writeShellScript "forgejo-runner-nix-cache-reset-${name}" ''
          set -euo pipefail
          exec 9>/run/lock/forgejo-runner-storage.lock
          ${pkgs.util-linux}/bin/flock 9

          vmUnit=${lib.escapeShellArg "microvm@${data.vmName}.service"}
          image=${lib.escapeShellArg cacheVolume.image}
          label=${lib.escapeShellArg cacheVolume.label}

          maskState="$(${pkgs.systemd}/bin/systemctl is-enabled "$vmUnit" 2>/dev/null || true)"
          case "$maskState" in
            masked|masked-runtime) ;;
            *) echo "Refusing Nix cache reset: $vmUnit must remain masked" >&2; exit 1 ;;
          esac
          activeState="$(${pkgs.systemd}/bin/systemctl is-active "$vmUnit" 2>/dev/null || true)"
          if [ "$activeState" != inactive ]; then
            echo "Refusing Nix cache reset: $vmUnit is $activeState, not inactive" >&2
            exit 1
          fi
          test "$(${pkgs.systemd}/bin/systemctl show --property=MainPID --value "$vmUnit")" -eq 0

          test -f "$image"
          test ! -L "$image"
          test "$(stat -c %h "$image")" -eq 1
          test "$(stat -c %s "$image")" -eq ${toString (cacheVolume.sizeMiB * 1024 * 1024)}
          case "$(${pkgs.e2fsprogs}/bin/lsattr -d "$image")" in *C*) ;; *) exit 1 ;; esac
          test "$(${pkgs.util-linux}/bin/blkid -s TYPE -o value "$image")" = ext4
          test "$(${pkgs.util-linux}/bin/blkid -s LABEL -o value "$image")" = "$label"
          if ${pkgs.util-linux}/bin/findmnt --raw --noheadings --source "$image" | ${pkgs.gnugrep}/bin/grep -q .; then
            echo "Refusing Nix cache reset: $image is mounted" >&2
            exit 1
          fi
          if ${pkgs.util-linux}/bin/losetup -j "$image" | ${pkgs.gnugrep}/bin/grep -q .; then
            echo "Refusing Nix cache reset: $image is attached to a loop device" >&2
            exit 1
          fi
          openHandleStatus=0
          ${openHandleProbe} "$image" /proc || openHandleStatus=$?
          case "$openHandleStatus" in
            0) ;;
            1)
              echo "Refusing Nix cache reset: a process has $image open" >&2
              exit 1
              ;;
            2)
              echo "Refusing Nix cache reset: open-handle enumeration failed" >&2
              exit 1
              ;;
            *)
              echo "Refusing Nix cache reset: open-handle probe returned unexpected status $openHandleStatus" >&2
              exit 1
              ;;
          esac

          ${pkgs.e2fsprogs}/bin/mkfs.ext4 -F -L "$label" "$image"
          test "$(stat -c %s "$image")" -eq ${toString (cacheVolume.sizeMiB * 1024 * 1024)}
          case "$(${pkgs.e2fsprogs}/bin/lsattr -d "$image")" in *C*) ;; *) exit 1 ;; esac
          test "$(${pkgs.util-linux}/bin/blkid -s TYPE -o value "$image")" = ext4
          test "$(${pkgs.util-linux}/bin/blkid -s LABEL -o value "$image")" = "$label"
          ${pkgs.e2fsprogs}/bin/e2fsck -fn "$image"
          ${pkgs.coreutils}/bin/chown microvm:kvm "$image"
          ${pkgs.coreutils}/bin/chmod 0600 "$image"
          if [ -d ${lib.escapeShellArg data.nixCacheMigrationInterlock} ] && [ ! -L ${lib.escapeShellArg data.nixCacheMigrationInterlock} ]; then
            ${pkgs.coreutils}/bin/rm -f -- ${lib.escapeShellArg data.nixCacheMigrationInterlock}/reason
            ${pkgs.coreutils}/bin/rmdir -- ${lib.escapeShellArg data.nixCacheMigrationInterlock}
          fi
          echo "Reset only the persistent Nix cache for ${name}: $image"
        '';
      in
      {
        description = "Owner-invoked offline Nix cache reset for ${name}";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = cacheResetScript;
          StandardOutput = "journal+console";
          StandardError = "journal+console";
          UMask = "0077";
        };
      }
    )
  ) runners;

  cacheMigrationServices = lib.mapAttrs' (
    name: data:
    lib.nameValuePair "forgejo-runner-nix-cache-migrate-${name}" (
      let
        cacheVolume = lib.findFirst (
          volume: volume.fileName == "nix-cache.raw"
        ) (throw "missing Nix cache volume") (mkVolumes data);
        expectedBytes = cacheVolume.sizeMiB * 1024 * 1024;
        cacheMigrationScript = pkgs.writeShellScript "forgejo-runner-nix-cache-migrate-${name}" ''
          set -euo pipefail
          mkdir -p /run/lock
          exec 9>/run/lock/forgejo-runner-storage.lock
          ${pkgs.util-linux}/bin/flock 9

          vmUnit=${lib.escapeShellArg "microvm@${data.vmName}.service"}
          storageDir=${lib.escapeShellArg data.storageDir}
          cacheSubvolume=${lib.escapeShellArg cacheVolume.subvolume}
          image=${lib.escapeShellArg cacheVolume.image}
          interlock=${lib.escapeShellArg data.nixCacheMigrationInterlock}
          expectedBytes=${toString expectedBytes}
          reserveMiB=${toString cacheVolume.qgroupReserveMiB}

          test -d "$interlock"
          test ! -L "$interlock"
          test "$(stat -c %u "$interlock")" -eq 0
          test "$(stat -c %g "$interlock")" -eq 0
          test "$(stat -c %a "$interlock")" = 700
          test -f "$interlock/reason"
          test ! -L "$interlock/reason"

          maskState="$(${pkgs.systemd}/bin/systemctl is-enabled "$vmUnit" 2>/dev/null || true)"
          case "$maskState" in
            masked|masked-runtime) ;;
            *) echo "Refusing Nix cache migration: $vmUnit must remain masked" >&2; exit 1 ;;
          esac
          activeState="$(${pkgs.systemd}/bin/systemctl is-active "$vmUnit" 2>/dev/null || true)"
          test "$activeState" = inactive
          test "$(${pkgs.systemd}/bin/systemctl show --property=MainPID --value "$vmUnit")" -eq 0

          test "$(findmnt -n -o FSTYPE --target /var)" = btrfs
          test -d "$storageDir"
          test ! -L "$storageDir"
          btrfs subvolume show "$storageDir" >/dev/null
          test -d "$cacheSubvolume"
          test ! -L "$cacheSubvolume"
          btrfs subvolume show "$cacheSubvolume" >/dev/null
          test -f "$image"
          test ! -L "$image"
          test "$(stat -c %h "$image")" -eq 1
          oldBytes="$(stat -c %s "$image")"
          test "$oldBytes" -lt "$expectedBytes"
          test "$(blkid -s TYPE -o value "$image")" = ext4
          test "$(blkid -s LABEL -o value "$image")" = ${lib.escapeShellArg cacheVolume.label}
          if findmnt --raw --noheadings --source "$image" | ${pkgs.gnugrep}/bin/grep -q .; then
            echo "Refusing Nix cache migration: $image is mounted" >&2
            exit 1
          fi
          if losetup -j "$image" | ${pkgs.gnugrep}/bin/grep -q .; then
            echo "Refusing Nix cache migration: $image is attached to a loop device" >&2
            exit 1
          fi
          openHandleStatus=0
          ${openHandleProbe} "$image" /proc || openHandleStatus=$?
          test "$openHandleStatus" -eq 0
          test "$(df --output=avail -B1 /var | tail -n 1 | tr -d ' ')" -ge "$((expectedBytes + oldBytes))"

          oldMiB=$(( (oldBytes + 1048575) / 1048576 ))
          temporaryLimitMiB=$((oldMiB + ${toString cacheVolume.sizeMiB} + reserveMiB))
          btrfs qgroup limit "''${temporaryLimitMiB}M" "$cacheSubvolume"
          timestamp="$(${pkgs.coreutils}/bin/date --utc +%Y%m%dT%H%M%SZ)"
          retired="$cacheSubvolume/.nix-cache.raw.retired-$timestamp"
          test ! -e "$retired"
          test ! -L "$retired"
          mv -- "$image" "$retired"
          temporaryImage="$(${pkgs.coreutils}/bin/mktemp "$cacheSubvolume/.nix-cache.raw.XXXXXX")"
          trap '${pkgs.coreutils}/bin/rm -f -- "$temporaryImage"' EXIT
          chattr +C "$temporaryImage"
          fallocate -l ${toString cacheVolume.sizeMiB}M "$temporaryImage"
          mkfs.ext4 -F -L ${lib.escapeShellArg cacheVolume.label} "$temporaryImage"
          test "$(stat -c %s "$temporaryImage")" -eq "$expectedBytes"
          case "$(lsattr -d "$temporaryImage")" in *C*) ;; *) exit 1 ;; esac
          test "$(blkid -s TYPE -o value "$temporaryImage")" = ext4
          test "$(blkid -s LABEL -o value "$temporaryImage")" = ${lib.escapeShellArg cacheVolume.label}
          e2fsck -fn "$temporaryImage"
          mv -- "$temporaryImage" "$image"
          trap - EXIT
          e2fsck -fn "$image"
          ${pkgs.coreutils}/bin/rm -f -- "$retired"
          btrfs qgroup limit ${
            toString (cacheVolume.sizeMiB + cacheVolume.qgroupReserveMiB)
          }M "$cacheSubvolume"
          chown microvm:kvm "$image"
          chmod 0600 "$image"
          ${pkgs.coreutils}/bin/rm -f -- "$interlock/reason"
          ${pkgs.coreutils}/bin/rmdir -- "$interlock"
          echo "Migrated only the persistent Nix cache for ${name}: $image"
        '';
      in
      {
        description = "Owner-invoked offline Nix cache migration for ${name}";
        requires = [ "${data.storageService}.service" ];
        after = [ "${data.storageService}.service" ];
        path = [
          pkgs.btrfs-progs
          pkgs.coreutils
          pkgs.e2fsprogs
          pkgs.gnugrep
          pkgs.util-linux
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = cacheMigrationScript;
          StandardOutput = "journal+console";
          StandardError = "journal+console";
          UMask = "0077";
        };
      }
    )
  ) runners;

  cacheGuardServices = lib.mapAttrs' (
    name: data:
    lib.nameValuePair data.nixCacheGuardService {
      description = "Block Forgejo runner ${name} until its Nix cache image is migrated";
      requires = [ "${data.storageService}.service" ];
      after = [ "${data.storageService}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "${data.nixCacheGuardService}" ''
          set -euo pipefail
          image=${lib.escapeShellArg data.nixCacheImage}
          interlock=${lib.escapeShellArg data.nixCacheMigrationInterlock}
          expectedBytes=${toString (data.runner.resources.nixCacheMiB * 1024 * 1024)}
          test -f "$image"
          test ! -L "$image"
          if [ "$(stat -c %s "$image")" -ne "$expectedBytes" ]; then
            install -d -m 0700 "$interlock"
            printf '%s\n' 'Nix cache image size differs from the declared cache size; run the owner migration service while the VM is masked and inactive' >"$interlock/reason"
            chmod 0600 "$interlock/reason"
            echo "Nix cache migration required before runner startup: $image" >&2
            exit 1
          fi
          if [ -e "$interlock" ] || [ -L "$interlock" ]; then
            echo "Nix cache migration interlock remains armed: $interlock" >&2
            exit 1
          fi
        '';
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
    }
  ) runners;

  dockerRecoveryServices = lib.mapAttrs' (
    name: data:
    lib.nameValuePair "forgejo-runner-docker-recovery-${name}" (
      let
        volumes = mkVolumes data;
        dockerVolume = lib.findFirst (
          volume: volume.fileName == "docker.raw"
        ) (throw "missing Docker volume") volumes;
        stagingSubvolume = "${data.storageDir}/.docker-recovery";
        stagingVolume = dockerVolume // {
          subvolume = stagingSubvolume;
          image = "${stagingSubvolume}/docker.raw";
          recoveryInterlock = null;
        };
        qgroupLimitBytes = (dockerVolume.sizeMiB + dockerVolume.qgroupReserveMiB) * 1024 * 1024;
        reserveFloorBytes = builtins.div (
          dockerVolume.qgroupReserveMiB * data.runner.resources.qgroupReserveFloorPercent * 1024 * 1024
        ) 100;
        protectedImages = [
          data.stateImage
          data.nixCacheImage
          data.workImage
        ];
        recoveryScript = pkgs.writeShellScript "forgejo-runner-docker-recovery-${name}" ''
          set -euo pipefail
          exec 9>/run/lock/forgejo-runner-storage.lock
          flock 9

          vmUnit=${lib.escapeShellArg "microvm@${data.vmName}.service"}
          storageDir=${lib.escapeShellArg data.storageDir}
          dockerSubvolume=${lib.escapeShellArg data.dockerSubvolume}
          dockerImage=${lib.escapeShellArg data.dockerImage}
          recoveryInterlock=${lib.escapeShellArg data.recoveryInterlock}
          recoveryCompletion="$recoveryInterlock/complete"
          stagingSubvolume=${lib.escapeShellArg stagingSubvolume}
          stagingImage=${lib.escapeShellArg stagingVolume.image}

          test -d "$recoveryInterlock"
          test ! -L "$recoveryInterlock"
          test "$(stat -c %u "$recoveryInterlock")" -eq 0
          test "$(stat -c %g "$recoveryInterlock")" -eq 0
          test "$(stat -c %a "$recoveryInterlock")" = 700
          test -z "$(find "$recoveryInterlock" -mindepth 1 -maxdepth 1 -print -quit)"

          maskState="$(systemctl is-enabled "$vmUnit" 2>/dev/null || true)"
          case "$maskState" in
            masked|masked-runtime) ;;
            *) echo "Refusing Docker recovery: $vmUnit must remain masked" >&2; exit 1 ;;
          esac
          activeState="$(systemctl is-active "$vmUnit" 2>/dev/null || true)"
          if [ "$activeState" != inactive ]; then
            echo "Refusing Docker recovery: $vmUnit is $activeState, not inactive" >&2
            exit 1
          fi
          test "$(systemctl show --property=MainPID --value "$vmUnit")" -eq 0

          test "$(findmnt -n -o FSTYPE --target /var)" = btrfs
          btrfs device stats -c /var
          test -d "$storageDir"
          test ! -L "$storageDir"
          btrfs subvolume show "$storageDir" >/dev/null
          test ! -e "$stagingSubvolume"
          test ! -L "$stagingSubvolume"

          protectedBefore="$(
            stat -c '%n|%D|%i|%s|%Y|%Z|%f|%u|%g' ${lib.escapeShellArgs protectedImages} | sha256sum
          )"
          for protectedImage in ${lib.escapeShellArgs protectedImages}; do
            test -f "$protectedImage"
            test ! -L "$protectedImage"
          done

          test -d "$dockerSubvolume"
          test ! -L "$dockerSubvolume"
          btrfs subvolume show "$dockerSubvolume" >/dev/null
          test -f "$dockerImage"
          test ! -L "$dockerImage"
          test "$(stat -c %h "$dockerImage")" -eq 1
          if findmnt --raw --noheadings --source "$dockerImage" | grep -q .; then
            echo "Refusing Docker recovery: $dockerImage is mounted" >&2
            exit 1
          fi
          if losetup -j "$dockerImage" | grep -q .; then
            echo "Refusing Docker recovery: $dockerImage is attached to a loop device" >&2
            exit 1
          fi
          openHandleStatus=0
          ${openHandleProbe} "$dockerImage" /proc || openHandleStatus=$?
          case "$openHandleStatus" in
            0) ;;
            1)
              echo "Refusing Docker recovery: a process has $dockerImage open" >&2
              exit 1
              ;;
            2)
              echo "Refusing Docker recovery: open-handle enumeration failed" >&2
              exit 1
              ;;
            *)
              echo "Refusing Docker recovery: open-handle probe returned unexpected status $openHandleStatus" >&2
              exit 1
              ;;
          esac
          echo "The masked, inactive VM has no Docker daemon or containers running"

          validateQgroup() {
            local subvolume="$1"
            local qgroupReport qgroupId referenced exclusive maxReferenced maxExclusive remaining
            qgroupReport="$(btrfs qgroup show -re --raw --sync /var 2>&1)"
            if printf '%s\n' "$qgroupReport" | grep -qi inconsistent; then
              printf '%s\n' "$qgroupReport" >&2
              echo "Refusing Docker recovery: Btrfs qgroup accounting is inconsistent" >&2
              return 1
            fi
            qgroupId="0/$(btrfs inspect-internal rootid "$subvolume")"
            read -r referenced exclusive maxReferenced maxExclusive < <(
              printf '%s\n' "$qgroupReport" | awk -v id="$qgroupId" '$1 == id { print $2, $3, $4, $5; found=1 } END { if (!found) exit 1 }'
            )
            if [ "$maxReferenced" -ne ${toString qgroupLimitBytes} ]; then
              echo "Refusing Docker recovery: $subvolume has qgroup maximum $maxReferenced, expected ${toString qgroupLimitBytes}" >&2
              return 1
            fi
            remaining=$((maxReferenced - referenced))
            printf '%s: qgroup=%s referenced=%s exclusive=%s max-referenced=%s max-exclusive=%s remaining=%s reserve-floor=%s\n' "$subvolume" "$qgroupId" "$referenced" "$exclusive" "$maxReferenced" "$maxExclusive" "$remaining" ${toString reserveFloorBytes}
            if [ "$remaining" -lt ${toString reserveFloorBytes} ]; then
              echo "Refusing Docker recovery: $subvolume is below its qgroup reserve floor" >&2
              return 1
            fi
          }

          validateQgroup "$dockerSubvolume"
          if [ "$(df --output=avail -B1 /var | tail -n 1 | tr -d ' ')" -lt ${toString qgroupLimitBytes} ]; then
            echo "Refusing Docker recovery: insufficient host space for a separate replacement" >&2
            exit 1
          fi

          oldFsckStatus=0
          e2fsck -fn "$dockerImage" || oldFsckStatus=$?
          case "$oldFsckStatus" in
            4) ;;
            *)
              echo "Refusing Docker recovery: expected e2fsck status 4 for the known damaged image, got $oldFsckStatus" >&2
              exit 1
              ;;
          esac

          btrfs subvolume create "$stagingSubvolume"
          btrfs qgroup limit ${
            toString (dockerVolume.sizeMiB + dockerVolume.qgroupReserveMiB)
          }M "$stagingSubvolume"
          ${mkVolumeScript stagingVolume}
          e2fsck -fn "$stagingImage"
          validateQgroup "$stagingSubvolume"

          timestamp="$(date --utc +%Y%m%dT%H%M%SZ)"
          retired="$storageDir/docker.retired-$timestamp"
          test ! -e "$retired"
          test ! -L "$retired"
          mv -- "$dockerSubvolume" "$retired"
          mv -- "$stagingSubvolume" "$dockerSubvolume"

          test -f "$retired/docker.raw"
          test ! -L "$retired/docker.raw"
          btrfs subvolume show "$retired" >/dev/null
          test -f "$dockerImage"
          test ! -L "$dockerImage"
          test "$(stat -c %s "$dockerImage")" -eq ${toString (dockerVolume.sizeMiB * 1024 * 1024)}
          case "$(lsattr -d "$dockerImage")" in *C*) ;; *) exit 1 ;; esac
          test "$(blkid -s TYPE -o value "$dockerImage")" = ext4
          test "$(blkid -s LABEL -o value "$dockerImage")" = ${lib.escapeShellArg dockerVolume.label}
          e2fsck -fn "$dockerImage"
          validateQgroup "$dockerSubvolume"

          protectedAfter="$(
            stat -c '%n|%D|%i|%s|%Y|%Z|%f|%u|%g' ${lib.escapeShellArgs protectedImages} | sha256sum
          )"
          test "$protectedAfter" = "$protectedBefore"

          completionTemporary="$(mktemp "$recoveryInterlock/.complete.XXXXXX")"
          trap 'rm -f -- "$completionTemporary"' EXIT
          printf '%s\n' ${lib.escapeShellArg "forgejo-runner-docker-recovery:${name}"} >"$completionTemporary"
          chmod 0600 "$completionTemporary"
          mv -- "$completionTemporary" "$recoveryCompletion"
          trap - EXIT
          printf 'Docker recovery complete. Retired evidence: %s\nReplacement: %s\nRecovery interlock remains armed: %s\n' "$retired/docker.raw" "$dockerImage" "$recoveryInterlock"
        '';
      in
      {
        description = "Offline retirement and recreation of disposable Docker storage for ${name}";
        path = [
          pkgs.btrfs-progs
          pkgs.coreutils
          pkgs.e2fsprogs
          pkgs.findutils
          pkgs.gawk
          pkgs.gnugrep
          pkgs.util-linux
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = recoveryScript;
          StandardOutput = "journal+console";
          StandardError = "journal+console";
          UMask = "0077";
        };
      }
    )
  ) runners;

  dockerRecoveryClearServices = lib.mapAttrs' (
    name: data:
    lib.nameValuePair "forgejo-runner-docker-recovery-clear-${name}" (
      let
        clearScript = pkgs.writeShellScript "forgejo-runner-docker-recovery-clear-${name}" ''
          set -euo pipefail
          exec 9>/run/lock/forgejo-runner-storage.lock
          ${pkgs.util-linux}/bin/flock 9

          vmUnit=${lib.escapeShellArg "microvm@${data.vmName}.service"}
          recoveryInterlock=${lib.escapeShellArg data.recoveryInterlock}
          recoveryCompletion="$recoveryInterlock/complete"

          activeState="$(${pkgs.systemd}/bin/systemctl is-active "$vmUnit" 2>/dev/null || true)"
          if [ "$activeState" != inactive ]; then
            echo "Refusing to clear Docker recovery interlock: $vmUnit is $activeState, not inactive" >&2
            exit 1
          fi
          test "$(${pkgs.systemd}/bin/systemctl show --property=MainPID --value "$vmUnit")" -eq 0
          test -d "$recoveryInterlock"
          test ! -L "$recoveryInterlock"
          test "$(${pkgs.coreutils}/bin/stat -c %u "$recoveryInterlock")" -eq 0
          test "$(${pkgs.coreutils}/bin/stat -c %g "$recoveryInterlock")" -eq 0
          test "$(${pkgs.coreutils}/bin/stat -c %a "$recoveryInterlock")" = 700
          test -f "$recoveryCompletion"
          test ! -L "$recoveryCompletion"
          test "$(${pkgs.coreutils}/bin/stat -c %u "$recoveryCompletion")" -eq 0
          test "$(${pkgs.coreutils}/bin/stat -c %g "$recoveryCompletion")" -eq 0
          test "$(${pkgs.coreutils}/bin/stat -c %a "$recoveryCompletion")" = 600
          test "$(${pkgs.coreutils}/bin/stat -c %h "$recoveryCompletion")" -eq 1
          test "$(< "$recoveryCompletion")" = ${lib.escapeShellArg "forgejo-runner-docker-recovery:${name}"}
          test "$(${pkgs.findutils}/bin/find "$recoveryInterlock" -mindepth 1 -maxdepth 1 -printf '%f\n')" = complete
          ${pkgs.coreutils}/bin/rm -- "$recoveryCompletion"
          ${pkgs.coreutils}/bin/rmdir -- "$recoveryInterlock"
          echo "Cleared reviewed Docker recovery interlock for ${name}"
        '';
      in
      {
        description = "Clear the reviewed Docker recovery interlock for ${name}";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = clearScript;
          StandardOutput = "journal+console";
          StandardError = "journal+console";
          UMask = "0077";
        };
      }
    )
  ) runners;

  dependencyServices = lib.mkMerge (
    lib.mapAttrsToList (name: data: {
      "install-microvm-${data.vmName}" = {
        requires = [ "${data.storageService}.service" ];
        after = [ "${data.storageService}.service" ];
      };
      "microvm-tap-interfaces@${data.vmName}" = {
        requires = [
          "${data.storageService}.service"
          firewallGuardUnit
        ];
        after = [
          "${data.storageService}.service"
          firewallGuardUnit
        ];
        bindsTo = [ firewallGuardUnit ];
      };
      "microvm@${data.vmName}" = {
        requires = [
          firewallGuardUnit
          "${data.proxyService}.service"
          "${data.nixCacheGuardService}.service"
        ];
        after = [
          firewallGuardUnit
          "${data.proxyService}.service"
          "${data.nixCacheGuardService}.service"
        ];
        wants = lib.optional data.runner.egress.enable "${data.egressService}.service";
        bindsTo = [ firewallGuardUnit ];
        unitConfig.ConditionPathExists = [
          "!${data.recoveryInterlock}"
          "!${data.resetInterlock}"
        ];
        serviceConfig.MemoryMax = "10G";
      };
    }) runners
  );

  proxyServices = lib.mapAttrs' (
    name: data:
    lib.nameValuePair data.proxyService {
      description = "Private Forgejo proxy for runner ${name}";
      requires = [ "microvm-tap-interfaces@${data.vmName}.service" ];
      after = [
        "microvm-tap-interfaces@${data.vmName}.service"
        "forgejo.service"
      ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        XDG_CACHE_HOME = "/var/cache/${data.proxyService}";
        XDG_CONFIG_HOME = "/var/lib/${data.proxyService}";
        XDG_DATA_HOME = "/var/lib/${data.proxyService}";
      };
      serviceConfig = {
        User = "forgejo-runner-proxy";
        Group = "forgejo-runner-proxy";
        ExecStart = "${pkgs.caddy}/bin/caddy run --config ${mkCaddyfile data} --adapter caddyfile";
        Restart = "on-failure";
        RuntimeDirectory = data.proxyService;
        StateDirectory = data.proxyService;
        CacheDirectory = data.proxyService;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_UNIX"
        ];
        IPAddressDeny = "any";
        IPAddressAllow = [
          "127.0.0.0/8"
          "${data.hostAddress}/32"
          "${data.guestAddress}/32"
        ];
      };
    }
  ) runners;

  egressProxyServices = lib.mapAttrs' (
    name: data:
    lib.nameValuePair data.egressService (
      lib.mkIf data.runner.egress.enable {
        description = "Public TCP/443 CONNECT proxy for Forgejo runner ${name}";
        requires = [ "microvm-tap-interfaces@${data.vmName}.service" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "microvm-tap-interfaces@${data.vmName}.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          DynamicUser = true;
          ExecStartPre = [
            "${pkgs.coreutils}/bin/install -m 0600 /dev/null /run/${data.egressService}/egress-errors.log"
            "${pkgs.squid}/bin/squid -k parse -f ${mkEgressConfig data}"
          ];
          ExecStart = "${pkgs.squid}/bin/squid -N -f ${mkEgressConfig data}";
          CPUQuota = "50%";
          MemoryHigh = "192M";
          MemoryMax = "256M";
          MemorySwapMax = 0;
          TasksMax = 128;
          LimitNOFILE = 4096;
          Restart = "on-failure";
          RestartSec = 2;
          RuntimeDirectory = data.egressService;
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          SystemCallArchitectures = "native";
          IPAddressDeny = blockedDestinationRanges;
          IPAddressAllow = [
            "${data.hostAddress}/32"
            "${data.guestAddress}/32"
          ];
        };
      }
    )
  ) runners;

  firewallGuardService = {
    forgejo-runner-firewall-guard = {
      description = "Reassert Forgejo runner TAP isolation";
      requires = [ "firewall.service" ];
      after = [ "firewall.service" ] ++ lib.optional config.virtualisation.docker.enable "docker.service";
      partOf = [ "firewall.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = firewallGuardScript;
        ExecReload = firewallGuardScript;
      };
    };
  };

  firewallLifecycleServices = lib.mkMerge [
    {
      firewall = {
        wants = [ firewallGuardUnit ];
        unitConfig.PropagatesReloadTo = [ firewallGuardUnit ];
      };
    }
    (lib.mkIf config.virtualisation.docker.enable {
      docker = {
        wants = [ firewallGuardUnit ];
        unitConfig.PropagatesReloadTo = [ firewallGuardUnit ];
        serviceConfig.ExecStartPost = lib.mkAfter [ firewallGuardScript ];
      };
    })
  ];
in
{
  config = lib.mkMerge [
    {
      microvm.host.enable = runnerEnabled && runners != { };
    }
    (lib.mkIf (runnerEnabled && runners != { }) {
      assertions = [
        {
          assertion = config.networking.firewall.enable;
          message = "Forgejo runner VMs require the host firewall.";
        }
        {
          assertion = config.networking.firewall.backend == "iptables";
          message = "Forgejo runner VMs require the iptables firewall backend.";
        }
        {
          assertion = forgejoCfg.upstream.host == "127.0.0.1" && forgejoCfg.upstream.port == 3000;
          message = "Forgejo runner VMs require Forgejo at 127.0.0.1:3000.";
        }
        {
          assertion =
            lib.length (lib.unique (map (data: data.runner.subnet) runnerData)) == lib.length runnerData;
          message = "Forgejo runner subnets must be unique.";
        }
        {
          assertion =
            lib.length (lib.unique (map (data: data.runner.tapName) runnerData)) == lib.length runnerData;
          message = "Forgejo runner TAP names must be unique.";
        }
        {
          assertion = lib.length (lib.unique (map (data: data.vmName) runnerData)) == lib.length runnerData;
          message = "Forgejo runner VM names must be unique.";
        }
        {
          assertion =
            lib.length (
              lib.unique (
                lib.concatMap (data: [
                  data.storageDir
                  data.vmStateDir
                ]) runnerData
              )
            ) == 2 * lib.length runnerData;
          message = "Forgejo runner storage and microVM state paths must not collide.";
        }
        {
          assertion =
            lib.length (lib.unique (map (data: data.runner.macAddress) runnerData)) == lib.length runnerData;
          message = "Forgejo runner MAC addresses must be unique.";
        }
        {
          assertion =
            lib.length (lib.unique (map (data: data.runner.runner.tokenSecret) runnerData))
            == lib.length runnerData;
          message = "Forgejo runner token secret names must be unique.";
        }
        {
          assertion =
            let
              endpoints = lib.concatMap (
                data:
                [ "${data.hostAddress}:${toString data.runner.forgejoProxyPort}" ]
                ++ lib.optional data.runner.egress.enable "${data.hostAddress}:${toString data.runner.egress.proxyPort}"
              ) runnerData;
            in
            lib.length (lib.unique endpoints) == lib.length endpoints;
          message = "Forgejo runner proxy bind addresses must be unique.";
        }
        {
          assertion =
            lib.length (lib.unique (map (data: data.hostAddress) runnerData)) == lib.length runnerData
            && lib.length (lib.unique (map (data: data.guestAddress) runnerData)) == lib.length runnerData;
          message = "Forgejo runner host and guest addresses must be unique.";
        }
        {
          assertion =
            lib.length (lib.unique (map (data: data.runner.runner.name) runnerData)) == lib.length runnerData;
          message = "Registered Forgejo runner names must be unique.";
        }
        {
          assertion =
            lib.length (lib.unique (map (data: data.runner.runner.tokenSopsFile) runnerData))
            == lib.length runnerData;
          message = "Forgejo runner token SOPS files must be unique.";
        }
        {
          assertion = lib.all (name: builtins.match "^[A-Za-z0-9_]+$" name != null) runnerNames;
          message = "Forgejo runner attribute names may contain only letters, digits, and underscores.";
        }
        {
          assertion = lib.all runnerNetworkValid runnerData;
          message = "Each Forgejo runner must explicitly use .1 for the host and .2 for the guest in its aligned /30 subnet.";
        }
        {
          assertion = lib.all (
            data: lib.all (imageName: builtins.hasAttr imageName runnerCfg.images) data.runner.runner.imageNames
          ) runnerData;
          message = "Every Forgejo runner imageNames entry must exist in actions.images.";
        }
        {
          assertion = lib.all runnerLabelsValid runnerData;
          message = "Forgejo runner labels must use only Docker images selected for offline seeding.";
        }
        {
          assertion = lib.all runnerNixSeedValid runnerData;
          message = "Every selected runner image must carry the configured compatible Nix seed epoch.";
        }
        {
          assertion = runnerCfg.nixCacheMinFreeMiB < runnerCfg.nixCacheMaxFreeMiB;
          message = "Forgejo runner Nix image requires nixCacheMinFreeMiB < nixCacheMaxFreeMiB.";
        }
        {
          assertion = lib.all (
            data: runnerCfg.nixCacheMaxFreeMiB < data.runner.resources.nixCacheMiB
          ) runnerData;
          message = "Each Forgejo runner Nix cache requires maxFreeMiB < nixCacheMiB.";
        }
        {
          assertion = lib.all (
            data: qgroupLimitTotalMiB data <= data.runner.resources.qgroupLimitBudgetMiB
          ) runnerData;
          message = "Each Forgejo runner's derived qgroup limits must fit its reviewed qgroupLimitBudgetMiB host-capacity budget.";
        }
        {
          assertion = lib.all (
            data:
            let
              imageNames = data.runner.runner.imageNames;
              imageReferences = map (image: image.reference) data.images;
            in
            lib.length (lib.unique imageNames) == lib.length imageNames
            && lib.length (lib.unique imageReferences) == lib.length imageReferences
          ) runnerData;
          message = "Each Forgejo runner must select unique offline image names and references.";
        }
      ];

      networking.firewall = {
        extraCommands = toString firewallGuardScript;
        extraStopCommands = toString firewallCleanupScript;
      };

      security.wrappers.qemu-bridge-helper.enable = false;

      microvm = {
        stateDir = "/var/lib/microvms";
        vms = lib.mapAttrs' (
          _: data:
          lib.nameValuePair data.vmName {
            autostart = true;
            specialArgs.hostConfig = config;
            config = mkGuest data;
          }
        ) runners;
      };

      users.groups.forgejo-runner-proxy = { };
      users.users.forgejo-runner-proxy = {
        isSystemUser = true;
        group = "forgejo-runner-proxy";
      };

      systemd.services = lib.mkMerge [
        storageServices
        cacheResetServices
        cacheMigrationServices
        cacheGuardServices
        dockerRecoveryServices
        dockerRecoveryClearServices
        dependencyServices
        proxyServices
        egressProxyServices
        firewallGuardService
        firewallLifecycleServices
      ];
    })
  ];
}
