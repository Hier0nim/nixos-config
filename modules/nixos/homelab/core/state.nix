{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  homelabMeta = import ../meta-data.nix;
  inherit (cfg) state;
  inherit (homelabMeta) immichBindTargets nixarrStateServices;

  mkStateDir = path: user: group: [
    "d ${path} 0750 ${user} ${group} - -"
    "Z ${path} 0750 ${user} ${group} - -"
  ];

  mkNixarrState =
    name:
    let
      svc = cfg.services.${name};
    in
    lib.optionals svc.enable (mkStateDir "${state.nixarr}/${name}" svc.user svc.group);

  # Private state under /var/lib/homelab/nixarr must stay svc.user:svc.group.
  # Shared groups are only for shared data paths under /data.
  mkNixarrStateOwnership =
    name:
    let
      svc = cfg.services.${name};
      statePath = "${state.nixarr}/${name}";
      owner = "${svc.user}:${svc.group}";
      esc = lib.escapeShellArg;
    in
    lib.mkIf svc.enable {
      users.groups.${svc.group} = { };
      users.users.${svc.user}.group = lib.mkForce svc.group;
      systemd.services.${name} = {
        serviceConfig = {
          PermissionsStartOnly = lib.mkForce true;
          User = lib.mkForce svc.user;
          Group = lib.mkForce svc.group;
          SupplementaryGroups = lib.mkAfter svc.dataGroups;
        };
        preStart = lib.mkBefore ''
          if [ -d ${esc statePath} ]; then
            chown -R ${esc owner} ${esc statePath}
          fi
        '';
      };
    };

  mkJellyfinPrivateIdentity =
    let
      svc = cfg.services.jellyfin;
      statePath = state.jellyfin;
      owner = "${svc.user}:${svc.group}";
      esc = lib.escapeShellArg;
    in
    lib.mkIf svc.enable {
      users.groups.${svc.group} = { };
      users.users.${svc.user}.group = lib.mkForce svc.group;
      systemd.services.jellyfin = {
        serviceConfig = {
          PermissionsStartOnly = lib.mkForce true;
          User = lib.mkForce svc.user;
          Group = lib.mkForce svc.group;
          SupplementaryGroups = lib.mkAfter svc.dataGroups;
        };
        preStart = lib.mkBefore ''
          if [ -d ${esc statePath} ]; then
            chown -R ${esc owner} ${esc statePath}
          fi
        '';
      };
    };

in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        systemd.tmpfiles.rules = lib.concatLists [
          [
            "d ${state.root} 0755 root root - -"
            "Z ${state.root} 0755 root root - -"
          ]
          (lib.optionals cfg.profiles.media.enable [
            "d ${state.nixarr} 0755 root root - -"
            "Z ${state.nixarr} 0755 root root - -"
          ])
          (lib.concatMap mkNixarrState nixarrStateServices)
          (lib.optionals cfg.services.jellyfin.enable (
            [
              "d ${state.jellyfin} 0750 ${cfg.services.jellyfin.user} ${cfg.services.jellyfin.group} - -"
              "Z ${state.jellyfin} 0750 ${cfg.services.jellyfin.user} ${cfg.services.jellyfin.group} - -"
            ]
            ++ mkStateDir "${state.jellyfin}/config" cfg.services.jellyfin.user cfg.services.jellyfin.group
            ++ mkStateDir "${state.jellyfin}/data" cfg.services.jellyfin.user cfg.services.jellyfin.group
            ++ mkStateDir "${state.jellyfin}/cache" cfg.services.jellyfin.user cfg.services.jellyfin.group
            ++ mkStateDir "${state.jellyfin}/log" cfg.services.jellyfin.user cfg.services.jellyfin.group
          ))
          (lib.optionals cfg.services.tdarr.enable (
            [
              "d ${state.tdarr} 0750 ${cfg.services.tdarr.user} ${cfg.services.tdarr.group} - -"
              "Z ${state.tdarr} 0750 ${cfg.services.tdarr.user} ${cfg.services.tdarr.group} - -"
            ]
            ++ mkStateDir "${state.tdarr}/server" cfg.services.tdarr.user cfg.services.tdarr.group
            ++ mkStateDir "${state.tdarr}/configs" cfg.services.tdarr.user cfg.services.tdarr.group
            ++ mkStateDir "${state.tdarr}/logs" cfg.services.tdarr.user cfg.services.tdarr.group
            ++ mkStateDir cfg.services.tdarr.cacheDir cfg.services.tdarr.user cfg.services.tdarr.group
          ))
          (lib.optionals (cfg.profiles.photos.enable && cfg.services.immich.enable) (
            [
              "d ${state.immichHot} 0750 ${cfg.services.immich.user} ${cfg.services.immich.group} - -"
              "Z ${state.immichHot} 0750 ${cfg.services.immich.user} ${cfg.services.immich.group} - -"
            ]
            ++ lib.concatMap (
              name: mkStateDir "${state.immichHot}/${name}" cfg.services.immich.user cfg.services.immich.group
            ) immichBindTargets
          ))
        ];

      }
      (lib.mkMerge (map mkNixarrStateOwnership nixarrStateServices))
      mkJellyfinPrivateIdentity
    ]
  );
}
