{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  inherit (cfg) state;
  stateApps = lib.filterAttrs (
    _: app: app.enable && (app.state.paths != [ ] || app.state.managedFiles != [ ])
  ) cfg.apps;

  mkAppStateDir = app: path: [
    "d ${path} ${app.state.mode} ${app.user} ${app.group} - -"
    "z ${path} ${app.state.mode} ${app.user} ${app.group} - -"
  ];

  mkAppStateFile = app: file: "f ${file.path} ${file.mode} ${app.user} ${app.group} - -";

  topLevelPaths =
    paths:
    lib.filter (
      path: !(lib.any (candidate: candidate != path && lib.hasPrefix "${candidate}/" path) paths)
    ) paths;

  mkRepairScript =
    {
      name,
      owner,
      group,
      paths,
      managedFiles,
    }:
    let
      esc = lib.escapeShellArg;
      fixOwner = "${owner}:${group}";
      repairDirs = lib.concatMapStringsSep "\n" (path: "repair_path ${esc path}") (topLevelPaths paths);
      repairFiles = lib.concatMapStringsSep "\n" (
        file: "repair_file ${esc file.path} ${esc file.mode}"
      ) managedFiles;
    in
    pkgs.writeShellScript "homelab-${name}-repair-permissions" ''
      set -euo pipefail

      repair_path() {
        path="$1"

        # Refuse to follow symlinks
        if [ -L "$path" ]; then
          echo "Refusing to follow symlink: $path" >&2
          exit 1
        fi

        if [ ! -e "$path" ]; then
          mkdir -p "$path"
        fi

        chown -R ${esc fixOwner} "$path"
        chmod -R u+rwX "$path"
      }

      repair_file() {
        path="$1"
        mode="$2"

        # Refuse to follow symlinks
        if [ -L "$path" ]; then
          echo "Refusing to follow symlink: $path" >&2
          exit 1
        fi

        if [ ! -e "$path" ]; then
          install -D -m "$mode" -o ${esc owner} -g ${esc group} /dev/null "$path"
        elif [ ! -f "$path" ]; then
          echo "Refusing to manage non-regular file: $path" >&2
          exit 1
        fi

        chown ${esc fixOwner} "$path"
        chmod "$mode" "$path"
      }

      ${repairDirs}
      ${repairFiles}
    '';

  mkStateRepair =
    {
      name,
      owner,
      group,
      paths,
      managedFiles,
      before ? [ ],
    }:
    let
      repairServiceName = "homelab-state-${name}";
      repairScript = mkRepairScript {
        inherit
          name
          owner
          group
          paths
          managedFiles
          ;
      };
    in
    {
      ${repairServiceName} = {
        description = "Repair permissions for ${name} state";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        inherit before;
        requires = [ "local-fs.target" ];
        path = [ pkgs.coreutils ];
        serviceConfig.Type = "oneshot";
        unitConfig.RequiresMountsFor = paths;
        script = "${repairScript}";
      };
    };

  mkAppStateRepair =
    name: app:
    let
      repairUnitName = "homelab-state-${name}.service";
    in
    lib.mkMerge [
      (mkStateRepair {
        inherit name;
        owner = app.user;
        inherit (app) group;
        paths = app.state.paths;
        managedFiles = app.state.managedFiles;
        before = map (serviceName: "${serviceName}.service") app.serviceNames;
      })
      (lib.genAttrs app.serviceNames (_: {
        after = lib.mkAfter [ repairUnitName ];
        requires = lib.mkAfter [ repairUnitName ];
      }))
    ];

in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        systemd.tmpfiles.rules = lib.concatLists [
          [
            "d ${state.root} 0755 root root - -"
            "z ${state.root} 0755 root root - -"
          ]
          (lib.optionals cfg.profiles.media.enable [
            "d ${state.nixflix} 0755 root root - -"
            "z ${state.nixflix} 0755 root root - -"
          ])
          (lib.flatten (
            lib.mapAttrsToList (_: app: lib.concatMap (mkAppStateDir app) app.state.paths) stateApps
          ))
          (lib.flatten (
            lib.mapAttrsToList (_: app: map (mkAppStateFile app) app.state.managedFiles) stateApps
          ))
        ];

        systemd.services = lib.mkMerge (lib.mapAttrsToList mkAppStateRepair stateApps);

      }
    ]
  );
}
