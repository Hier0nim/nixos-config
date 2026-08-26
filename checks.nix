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
  hostConfig = nixosConfigurations.server-legion.config;
  hostServices = hostConfig.systemd.services;
  runnerService = hostServices.gitea-runner-global;
  runnerInstance = hostConfig.services.gitea-actions-runner.instances.global;
  runnerTokenTemplate = hostConfig.sops.templates."forgejo-runner-token.env";
  stateRootUnit = hostServices.homelab-state-root;
  stateRepairUnits = map (name: hostServices."homelab-state-${name}") [
    "jellyfin"
    "radarr"
    "sonarr"
  ];
  nixflixSetupUnit = hostServices.nixflix-setup-dirs;
  forgejoSnapshotUnit = hostServices.homelab-forgejo-snapshot;
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

  "native-forgejo-runner-regression" = pkgs.runCommand "native-forgejo-runner-regression" { } ''
    labels=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerInstance.labels)}
    packages=${lib.escapeShellArg (lib.concatStringsSep "\n" (map toString runnerInstance.hostPackages))}
    packageNames=${lib.escapeShellArg (lib.concatStringsSep "\n" (map lib.getName runnerInstance.hostPackages))}
    nixPackage=${lib.escapeShellArg (lib.getName pkgs.nix)}
    zstdPackage=${lib.escapeShellArg (lib.getName pkgs.zstd)}
    rwPaths=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerService.serviceConfig.ReadWritePaths)}
    inaccessiblePaths=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerService.serviceConfig.InaccessiblePaths)}
    supplementaryGroups=${lib.escapeShellArg (lib.concatStringsSep "\n" runnerService.serviceConfig.SupplementaryGroups)}
    test "$labels" = nix:host
    test ${toString runnerInstance.settings.runner.capacity} -eq 1
    test ${lib.escapeShellArg runnerInstance.settings.runner.timeout} = 3h
    test ${lib.escapeShellArg runnerInstance.settings.host.workdir_parent} = /var/lib/gitea-runner/global/work
    test ${if runnerInstance.settings.cache.enabled then "true" else "false"} = true
    test ${lib.escapeShellArg runnerInstance.settings.cache.dir} = /var/lib/gitea-runner/global/actions-cache
    ${pkgs.gnugrep}/bin/grep -Fqx /var/lib/gitea-runner <<<"$rwPaths"
    ${pkgs.gnugrep}/bin/grep -Fqx /var/lib/homelab <<<"$inaccessiblePaths"
    test -z "$supplementaryGroups"
    test ${if runnerService.serviceConfig.DynamicUser then "true" else "false"} = false
    test ${lib.escapeShellArg runnerService.serviceConfig.User} = gitea-runner
    test ${lib.escapeShellArg runnerService.serviceConfig.Group} = gitea-runner
    test ${if runnerService.serviceConfig.NoNewPrivileges then "true" else "false"} = true
    test ${if runnerService.serviceConfig.PrivateTmp then "true" else "false"} = true
    test ${if runnerService.serviceConfig.PrivateDevices then "true" else "false"} = true
    test ${lib.escapeShellArg runnerService.serviceConfig.ProtectSystem} = strict
    test ${if runnerService.serviceConfig.ProtectHome then "true" else "false"} = true
    test ${if runnerService.serviceConfig.ProtectKernelTunables then "true" else "false"} = true
    test ${if runnerService.serviceConfig.ProtectKernelModules then "true" else "false"} = true
    test ${if runnerService.serviceConfig.ProtectControlGroups then "true" else "false"} = true
    test -z ${lib.escapeShellArg runnerService.serviceConfig.CapabilityBoundingSet}
    test -z ${lib.escapeShellArg runnerService.serviceConfig.AmbientCapabilities}
    test ${if runnerService.serviceConfig.RestrictSUIDSGID then "true" else "false"} = true
    test ${lib.escapeShellArg runnerService.serviceConfig.UMask} = 0077
    test ${lib.escapeShellArg runnerInstance.tokenFile} = ${lib.escapeShellArg runnerTokenTemplate.path}
    test ${lib.escapeShellArg runnerTokenTemplate.owner} = gitea-runner
    test ${lib.escapeShellArg runnerTokenTemplate.group} = gitea-runner
    test ${lib.escapeShellArg runnerTokenTemplate.mode} = 0400
    test ${lib.escapeShellArg (lib.concatStringsSep "\n" runnerTokenTemplate.restartUnits)} = gitea-runner-global.service
    test ${if hostConfig.nix.settings.sandbox then "true" else "false"} = true
    test ${if hostConfig.nix.settings.sandbox-fallback then "true" else "false"} = false
    ${pkgs.gnugrep}/bin/grep -Eq -- '-nodejs-24[.-]' <<<"$packages"
    ${pkgs.gnugrep}/bin/grep -Fqx "$nixPackage" <<<"$packageNames"
    ${pkgs.gnugrep}/bin/grep -Fqx "$zstdPackage" <<<"$packageNames"
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
