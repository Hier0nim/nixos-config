{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;

  mediaEnabled = cfg.profiles.media.enable;
  photosEnabled = cfg.profiles.photos.enable;
  filesEnabled = cfg.profiles.files.enable;

  roleGroups = {
    media = "media";
    downloads = "media";
    photos = "photos";
    nas = "nas";
  };

  storageGroups = app: map (role: roleGroups.${role}) app.storageAccess;

  mkUmaskOverride =
    app:
    lib.genAttrs app.serviceNames (_: {
      serviceConfig.UMask = lib.mkForce (if app.sharedWriter then "0002" else "0022");
    });

  mkServiceGroupOverride =
    app:
    let
      extraGroups = lib.unique (storageGroups app ++ app.supplementaryGroups);
    in
    lib.mkIf (extraGroups != [ ]) (
      lib.genAttrs app.serviceNames (_: {
        serviceConfig.SupplementaryGroups = lib.mkAfter extraGroups;
      })
    );

in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      users.groups =
        let
          enabledAppValues = lib.attrValues (lib.filterAttrs (_: app: app.enable) cfg.apps);
        in
        lib.mkMerge (
          [
            (lib.mkIf mediaEnabled { media = { }; })
            (lib.mkIf photosEnabled { photos = { }; })
            (lib.mkIf filesEnabled { nas = { }; })
          ]
          ++ map (
            app:
            lib.mkIf app.manageUser {
              ${app.group} = { };
            }
          ) enabledAppValues
        );

      users.users =
        let
          enabledAppValues = lib.attrValues (lib.filterAttrs (_: app: app.enable) cfg.apps);
        in
        lib.mkMerge (
          map (
            app:
            let
              extraGroups = lib.unique (storageGroups app ++ app.supplementaryGroups);
            in
            lib.mkMerge [
              (lib.mkIf app.manageUser {
                ${app.user} = {
                  group = lib.mkForce app.group;
                  isSystemUser = lib.mkDefault true;
                };
              })
              (lib.mkIf (extraGroups != [ ]) {
                ${app.user}.extraGroups = lib.mkAfter extraGroups;
              })
            ]
          ) enabledAppValues
        );

      systemd.services =
        let
          enabledAppValues = lib.attrValues (lib.filterAttrs (_: app: app.enable) cfg.apps);
        in
        lib.mkMerge (map mkUmaskOverride enabledAppValues ++ map mkServiceGroupOverride enabledAppValues);
    })

    {
      assertions =
        let
          enabledApps = lib.filterAttrs (_: app: app.enable) cfg.apps;

          allStatePaths = lib.flatten (lib.mapAttrsToList (_: app: app.state.paths) enabledApps);

          allManagedFiles = lib.flatten (
            lib.mapAttrsToList (_: app: map (f: f.path) app.state.managedFiles) enabledApps
          );

          allPaths = allStatePaths ++ allManagedFiles;

          forbiddenPrefixes = [
            "/"
            "/etc"
            "/usr"
            "/bin"
            "/sbin"
            "/boot"
            "/dev"
            "/proc"
            "/sys"
            "/run"
            "/nix"
          ];

          isForbidden =
            path:
            path == "/"
            || lib.any (prefix: path == prefix || lib.hasPrefix "${prefix}/" path) forbiddenPrefixes;

          invalidPaths = lib.filter isForbidden allPaths;
        in
        [
          {
            assertion = invalidPaths == [ ];
            message = "homelab.apps contains forbidden system paths: ${lib.concatStringsSep ", " invalidPaths}";
          }
          {
            assertion = lib.all (p: lib.hasPrefix "/" p) allPaths;
            message = "homelab.apps state paths must be absolute: ${
              lib.concatStringsSep ", " (lib.filter (p: !(lib.hasPrefix "/" p)) allPaths)
            }";
          }
        ];
    }
  ];
}
