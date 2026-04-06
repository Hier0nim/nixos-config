{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
  tdarrService = cfg.services.tdarr;
  inherit (config.networking) hostName;
  inherit (config.time) timeZone;
  inherit (cfg) data state;
  inherit (tdarrService) group image user;
  mediaGroupId = config.users.groups.media.gid;
  usingNvenc =
    tdarrService.hardwareAcceleration.enable && tdarrService.hardwareAcceleration.type == "nvenc";
  usingVaapi =
    tdarrService.hardwareAcceleration.enable && tdarrService.hardwareAcceleration.type == "vaapi";
in
{
  config = lib.mkIf (cfg.enable && cfg.profiles.media.enable && tdarrService.enable) {
    users.groups.${group} = { };
    users.users.${user} = {
      isSystemUser = true;
      inherit group;
    };

    virtualisation = {
      docker.enable = true;
      oci-containers = {
        backend = lib.mkDefault "docker";

        containers.tdarr = {
          autoStart = true;
          inherit image;
          ports = [
            "127.0.0.1:${toString tdarrService.upstream.port}:8265"
            "127.0.0.1:8266:8266"
          ];
          volumes = [
            "${state.tdarr}/server:/app/server"
            "${state.tdarr}/configs:/app/configs"
            "${state.tdarr}/logs:/app/logs"
            "${tdarrService.cacheDir}:/temp"
            "${data.media}:${data.media}"
          ];
          environment = {
            PUID = "0";
            PGID = toString mediaGroupId;
            TZ = timeZone;
            UMASK_SET = "002";
            serverIP = "0.0.0.0";
            serverPort = "8266";
            webUIPort = "8265";
            internalNode = "true";
            inContainer = "true";
            ffmpegVersion = "7";
            nodeName = "${hostName}-internal";
            openBrowser = "false";
            auth = "false";
          }
          // lib.optionalAttrs usingNvenc {
            NVIDIA_DRIVER_CAPABILITIES = "all";
            NVIDIA_VISIBLE_DEVICES = "all";
          };
          extraOptions =
            lib.optionals usingNvenc [
              "--device=nvidia.com/gpu=all"
            ]
            ++ lib.optionals usingVaapi [
              "--device=/dev/dri:/dev/dri"
            ];
        };
      };
    };

    hardware.nvidia-container-toolkit.enable = lib.mkIf usingNvenc true;
  };
}
