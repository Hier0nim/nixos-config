{
  config,
  homelabMeta,
  lib,
  ...
}:
let
  cfg = config.homelab;
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

  mkNixarrStateOwnership =
    name:
    let
      svc = cfg.services.${name};
      statePath = "${state.nixarr}/${name}";
      owner = "${svc.user}:${svc.group}";
      esc = lib.escapeShellArg;
    in
    lib.mkIf svc.enable {
      # Private state under /var/lib/homelab/nixarr must stay svc.user:svc.group.
      # Shared groups are only for shared data paths under /data.
      ${name}.preStart = lib.mkBefore ''
        if [ -d ${esc statePath} ]; then
          chown -R ${esc owner} ${esc statePath}
        fi
      '';
    };

in
{
  config = lib.mkIf cfg.enable {
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

    systemd.services = lib.mkMerge (map mkNixarrStateOwnership nixarrStateServices);
  };
}
