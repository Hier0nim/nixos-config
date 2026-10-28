{
  lib,
  pkgs,
  ...
}:
let
  photos = "/data/photos";
  hotRoot = "/var/lib/homelab/immich-hot";
  bindTargets = [
    "upload"
    "thumbs"
    "encoded-video"
    "profile"
  ];
  hotDirs = map (name: "${hotRoot}/${name}") bindTargets;
in
{
  users.users.immich.extraGroups = [
    "photos"
    "render"
    "video"
  ];

  services.immich = {
    enable = true;
    package = pkgs.immich;
    host = "127.0.0.1";
    port = 2283;
    openFirewall = false;
    mediaLocation = photos;
    accelerationDevices = [
      "/dev/nvidia0"
      "/dev/nvidiactl"
      "/dev/nvidia-modeset"
      "/dev/nvidia-uvm"
      "/dev/nvidia-uvm-tools"
    ];
    settings = {
      newVersionCheck.enabled = false;
      ffmpeg = {
        accel = "nvenc";
        accelDecode = true;
      };
      server.externalDomain = "https://fotki.pieczarkowo.me";
      storageTemplate = {
        enabled = true;
        hashVerificationEnabled = true;
        template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
      };
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/homelab 0755 root root - -"
      "d ${hotRoot} 0755 root root - -"
    ]
    ++ map (dir: "d ${dir} 2770 immich photos - -") hotDirs
    ++ map (name: "d ${photos}/${name} 2770 root photos - -") bindTargets;
    services.immich-server = {
      unitConfig.RequiresMountsFor = hotDirs;
      serviceConfig.PrivateUsers = lib.mkForce false;
    };
    tmpfiles.settings.immich = lib.mkForce { };
  };

  fileSystems = lib.listToAttrs (
    map (name: {
      name = "${photos}/${name}";
      value = {
        device = "${hotRoot}/${name}";
        fsType = "none";
        options = [
          "bind"
          "x-systemd.requires-mounts-for=${hotRoot}/${name}"
        ];
      };
    }) bindTargets
  );
}
