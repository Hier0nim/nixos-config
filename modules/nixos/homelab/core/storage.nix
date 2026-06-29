{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  inherit (cfg) data;
  homelabMeta = import ../meta-data.nix;
  inherit (homelabMeta) immichBindTargets;

  mediaEnabled = cfg.profiles.media.enable;
  photosEnabled = cfg.profiles.photos.enable;
  filesEnabled = cfg.profiles.files.enable;

  enabledApps = lib.filterAttrs (_: app: app.enable) cfg.apps;

  storageConsumers =
    role:
    lib.unique (
      lib.flatten (
        lib.mapAttrsToList (
          _: app: lib.optionals (builtins.elem role app.storageAccess) app.serviceNames
        ) enabledApps
      )
    );

  mkRepairScript =
    {
      name,
      owner,
      group,
      mode,
      paths,
      recursiveRepair ? false,
    }:
    let
      esc = lib.escapeShellArg;
      fixOwner = "${owner}:${group}";
      body = lib.concatMapStringsSep "\n" (path: "fix_dir ${esc path}") paths;
      recursiveFix = lib.optionalString recursiveRepair ''
        # Recursively fix descendants: dirs get setgid mode, files get group-writable
        for p in ${lib.concatMapStringsSep " " esc paths}; do
          if [ -d "$p" ]; then
            find "$p" -type d -exec chown ${esc fixOwner} {} \; -exec chmod ${mode} {} \;
            find "$p" -type f -exec chown ${esc fixOwner} {} \; -exec chmod 0664 {} \;
          fi
        done
      '';
    in
    pkgs.writeShellScript "homelab-${name}-repair-permissions" ''
      set -euo pipefail

      fix_dir() {
        dir="$1"

        # Refuse to follow symlinks - prevents symlink attacks
        if [ -L "$dir" ]; then
          echo "Refusing to follow symlink: $dir" >&2
          exit 1
        fi

        if [ ! -d "$dir" ]; then
          mkdir -p "$dir"
        fi

        setfacl -b "$dir"
        chown ${esc fixOwner} "$dir"
        chmod ${mode} "$dir"
      }

      ${body}
      ${recursiveFix}
    '';

  mkManagedTree =
    {
      name,
      root,
      group,
      mode,
      subdirs ? [ ],
      repair ? true,
      consumers ? [ ],
      recursiveRepair ? true,
      owner ? "root",
    }:
    let
      repairPaths = [ root ] ++ map (subdir: "${root}/${subdir}") subdirs;
      rulePrefix = if recursiveRepair then "Z" else "z";
      repairServiceName = "homelab-storage-${name}";
      repairUnitName = "${repairServiceName}.service";
      repairScript = mkRepairScript {
        inherit
          name
          owner
          group
          mode
          recursiveRepair
          ;
        paths = repairPaths;
      };
    in
    {
      tmpfilesRules = lib.concatMap (path: [
        "d ${path} ${mode} ${owner} ${group} - -"
        "${rulePrefix} ${path} ${mode} ${owner} ${group} - -"
      ]) repairPaths;

      systemdServices =
        lib.optionalAttrs repair {
          ${repairServiceName} = {
            description = "Repair permissions for ${root}";
            wantedBy = [ "multi-user.target" ];
            after = [ "local-fs.target" ];
            before = map (service: "${service}.service") consumers;
            requires = [ "local-fs.target" ];
            path = [
              pkgs.acl
              pkgs.coreutils
              pkgs.findutils
            ];
            serviceConfig.Type = "oneshot";
            unitConfig.RequiresMountsFor = repairPaths;
            script = "${repairScript}";
          };
        }
        // lib.genAttrs consumers (_: {
          after = lib.mkAfter [ repairUnitName ];
          requires = lib.mkAfter [ repairUnitName ];
        });

      inherit repairServiceName repairPaths;
    };

  managedTrees =
    lib.optionals mediaEnabled [
      (mkManagedTree {
        name = "media";
        root = data.media;
        group = "media";
        mode = "2775";
        subdirs = [
          "movies"
          "tv"
          "anime"
          "audiobooks"
          "books"
        ];
        consumers = storageConsumers "media";
      })

      (mkManagedTree {
        name = "downloads";
        root = data.downloads;
        group = "media";
        mode = "2775";
        subdirs = [
          "torrent"
          "torrent/audiobooks"
          "review"
          "review/audiobooks"
        ];
        consumers = storageConsumers "downloads";
      })
    ]
    ++ lib.optionals photosEnabled [
      (mkManagedTree {
        name = "photos";
        root = data.photos;
        group = "photos";
        mode = "2770";
        recursiveRepair = false;
        subdirs = [
          "library"
          "backups"
        ]
        ++ immichBindTargets;
        consumers = storageConsumers "photos";
      })
    ]
    ++ lib.optionals filesEnabled [
      (mkManagedTree {
        name = "nas";
        root = data.nas;
        group = "nas";
        mode = "2770";
        recursiveRepair = false;
        subdirs = [
          "shared"
          "hieronim"
          "sarka"
        ];
        consumers = storageConsumers "nas";
      })
    ];
in
{
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${data.root} 0755 root root - -"
      "z ${data.root} 0755 root root - -"
    ]
    ++ lib.concatLists (map (tree: tree.tmpfilesRules) managedTrees);

    systemd.services = lib.mkMerge (map (tree: tree.systemdServices) managedTrees);
  };
}
