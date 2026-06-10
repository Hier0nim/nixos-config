{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  immichService = cfg.services.immich;
  inherit (immichService.upstream) port;
  inherit (cfg.data) photos;
  inherit (cfg.state) immichHot;
  immichFqdn = "${immichService.expose.subdomain}.${cfg.domain}";
  homelabMeta = import ../meta-data.nix;
  inherit (homelabMeta) immichBindTargets;
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.photos.enable && immichService.enable) {
    homelab.apps.immich = {
      enable = true;
      inherit (immichService) user group;
      serviceNames = [ "immich-server" ];
      storageAccess = [ "photos" ];
      supplementaryGroups = lib.optionals immichService.hardwareAcceleration.enable [
        "render"
        "video"
      ];
      state.paths = [
        immichHot
      ]
      ++ map (name: "${immichHot}/${name}") immichBindTargets;
      state.managedFiles = [
        { path = "${photos}/library/.immich"; }
        { path = "${photos}/backups/.immich"; }
      ]
      ++ map (name: {
        path = "${immichHot}/${name}/.immich";
      }) immichBindTargets;
    };

    homelab.services.immich.backup = {
      enable = lib.mkDefault true;
      paths = lib.mkDefault [
        "${cfg.data.photos}/library"
        "${cfg.data.photos}/backups"
        "${cfg.data.photos}/profile"
      ];
      exclude = lib.mkDefault [
        "${cfg.data.photos}/upload"
        "${cfg.data.photos}/thumbs"
        "${cfg.data.photos}/encoded-video"
      ];
    };

    services.immich = {
      enable = true;
      host = "127.0.0.1";
      openFirewall = false;
      inherit port;

      # Canonical Immich media root
      mediaLocation = photos;

      accelerationDevices = lib.mkIf immichService.hardwareAcceleration.enable (
        [
          (toString immichService.hardwareAcceleration.device)
        ]
        ++ lib.optionals (immichService.hardwareAcceleration.type == "nvenc") [
          "/dev/nvidiactl"
          "/dev/nvidia-modeset"
          "/dev/nvidia-uvm"
          "/dev/nvidia-uvm-tools"
        ]
      );

      settings = {
        newVersionCheck.enabled = false;

        ffmpeg = lib.mkIf immichService.hardwareAcceleration.enable {
          accel = immichService.hardwareAcceleration.type;
          accelDecode = true;
        };

        server = {
          externalDomain = "https://${immichFqdn}";
        };

        storageTemplate = {
          enabled = true;
          hashVerificationEnabled = true;
          template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
        };
      };
    };

    systemd = {
      services.immich-server.unitConfig.RequiresMountsFor = map (
        name: "${photos}/${name}"
      ) immichBindTargets;

      # Immich needs host UID/GID semantics for group-owned media and bind-mounted
      # hot storage. A private user namespace remaps those owners to nobody:nogroup.
      services.immich-server.serviceConfig.PrivateUsers = lib.mkForce false;

      # The upstream module assumes a private 0700 media root. Shared photo
      # storage is instead owned exclusively by the homelab storage policy.
      tmpfiles.settings.immich = lib.mkForce { };
    };

    fileSystems = lib.listToAttrs (
      map (name: {
        name = "${photos}/${name}";
        value = {
          device = "${immichHot}/${name}";
          options = [
            "bind"
            "x-systemd.requires-mounts-for=${immichHot}/${name}"
          ];
        };
      }) immichBindTargets
    );
  };
}
