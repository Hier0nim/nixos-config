{ config, lib, ... }:
let
  cfg = config.homelab;
  homelabMeta = {
    proxiedServices = [
      "sonarr"
      "radarr"
      "prowlarr"
      "bazarr"
      "transmission"
      "jellyfin"
      "jellyseerr"
      "audiobookshelf"
      "readarr"
      "readarr-audiobook"
      "immich"
      "copyparty"
      "cockpit"
    ];

    nixarrStateServices = [
      "sonarr"
      "radarr"
      "prowlarr"
      "bazarr"
      "transmission"
      "jellyseerr"
      "audiobookshelf"
      "readarr"
      "readarr-audiobook"
    ];

    sharedRoles = {
      media = [
        "sonarr"
        "radarr"
        "bazarr"
        "transmission"
        "jellyfin"
        "audiobookshelf"
        "readarr"
        "readarr-audiobook"
      ];
      photos = [ "immich" ];
      nas = [ "copyparty" ];
    };

    umaskSharedWriters = [
      "transmission"
      "sonarr"
      "radarr"
      "bazarr"
      "readarr"
      "readarr-audiobook"
      "audiobookshelf"
    ];

    immichBindTargets = [
      "upload"
      "thumbs"
      "encoded-video"
      "profile"
    ];
  };
  hasService = name: builtins.hasAttr name cfg.services;
  allExist = names: builtins.all hasService names;
  inherit (homelabMeta) sharedRoles;
  sharedRoleNames = lib.flatten (builtins.attrValues sharedRoles);
  uniqueList = names: builtins.length (lib.unique names) == builtins.length names;
in
{
  _module.args.homelabMeta = homelabMeta;

  assertions = lib.optionals cfg.enable [
    {
      assertion = allExist homelabMeta.proxiedServices;
      message = "homelabMeta.proxiedServices contains unknown service names.";
    }
    {
      assertion = allExist homelabMeta.nixarrStateServices;
      message = "homelabMeta.nixarrStateServices contains unknown service names.";
    }
    {
      assertion = allExist sharedRoleNames;
      message = "homelabMeta.sharedRoles contains unknown service names.";
    }
    {
      assertion = allExist homelabMeta.umaskSharedWriters;
      message = "homelabMeta.umaskSharedWriters contains unknown service names.";
    }
    {
      assertion = uniqueList homelabMeta.proxiedServices;
      message = "homelabMeta.proxiedServices contains duplicate entries.";
    }
    {
      assertion = uniqueList homelabMeta.nixarrStateServices;
      message = "homelabMeta.nixarrStateServices contains duplicate entries.";
    }
    {
      assertion = uniqueList homelabMeta.umaskSharedWriters;
      message = "homelabMeta.umaskSharedWriters contains duplicate entries.";
    }
    {
      assertion = uniqueList sharedRoles.media;
      message = "homelabMeta.sharedRoles.media contains duplicate entries.";
    }
    {
      assertion = uniqueList sharedRoles.photos;
      message = "homelabMeta.sharedRoles.photos contains duplicate entries.";
    }
    {
      assertion = uniqueList sharedRoles.nas;
      message = "homelabMeta.sharedRoles.nas contains duplicate entries.";
    }
  ];
}
