{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  svc = cfg.services."llama-cpp-agent";
  portMacro = "$" + "{PORT}";
  modelIdMacro = "$" + "{MODEL_ID}";
  apiKeyPath =
    if svc.apiKeySecretName != null then config.sops.secrets.${svc.apiKeySecretName}.path else null;

  modelPathInContainer = "/models/${svc.modelFile}";

  serverArgs = [
    "-m"
    modelPathInContainer

    "-ngl"
    (toString svc.gpuLayers)

    "-c"
    (toString svc.contextSize)

    "--host"
    "0.0.0.0"

    "--port"
    (toString svc.upstream.port)

    "--cache-type-k"
    svc.cacheTypeK

    "--cache-type-v"
    svc.cacheTypeV
  ]
  ++ lib.optionals (svc.cpuMoeLayers != null) [
    "--n-cpu-moe"
    (toString svc.cpuMoeLayers)
  ]
  ++ lib.optionals svc.noMmap [
    "--no-mmap"
  ]
  ++ lib.optionals svc.mlock [
    "--mlock"
  ]
  ++ lib.optionals svc.flashAttention [
    "--flash-attn"
  ]
  ++ lib.optionals (apiKeyPath != null) [
    "--api-key-file"
    "/run/secrets/llama-cpp-agent-api-key"
  ];

  gpuRunOptions = if svc.gpu.useCdi then [ "--device=nvidia.com/gpu=all" ] else [ "--gpus=all" ];

  dockerRunCommand = lib.concatStringsSep " " (
    [
      "docker"
      "run"
      "--init"
      "--rm"
      "--name"
      modelIdMacro
      "--ipc=host"
      "--publish"
      "${portMacro}:8080"
      "--volume"
      "${toString svc.modelDir}:/models:ro"
    ]
    ++ lib.optionals (apiKeyPath != null) [
      "--volume"
      "${toString apiKeyPath}:/run/secrets/llama-cpp-agent-api-key:ro"
    ]
    ++ lib.optionals svc.gpu.enable (
      [
        "--env"
        "NVIDIA_VISIBLE_DEVICES=all"
        "--env"
        "NVIDIA_DRIVER_CAPABILITIES=compute,utility"
      ]
      ++ gpuRunOptions
    )
    ++ lib.optionals svc.mlock [
      "--ulimit"
      "memlock=-1:-1"
    ]
    ++ [
      svc.image
    ]
    ++ serverArgs
  );

  llamaSwapConfig = {
    healthCheckTimeout = 600;
    models.qwen = {
      name = "Qwen 3.6 35B A3B";
      ttl = svc.dynamicStart.idleStopMinutes * 60;
      cmd = dockerRunCommand;
      cmdStop = "docker stop ${modelIdMacro}";
    };
  };
in
{
  config = lib.mkIf (cfg.enable && svc.enable) {
    assertions = [
      {
        assertion = svc.modelFile != "";
        message = "homelab.services.llama-cpp-agent.modelFile must not be empty.";
      }
      {
        assertion = svc.contextSize > 0;
        message = "homelab.services.llama-cpp-agent.contextSize must be greater than 0.";
      }
      {
        assertion = svc.gpuLayers >= 0;
        message = "homelab.services.llama-cpp-agent.gpuLayers must be greater than or equal to 0.";
      }
      {
        assertion = svc.dynamicStart.idleStopMinutes >= 0;
        message = "homelab.services.llama-cpp-agent.dynamicStart.idleStopMinutes must be greater than or equal to 0.";
      }
      {
        assertion =
          apiKeyPath != null
          || (!svc.openFirewall && svc.bindAddress == "127.0.0.1" && !svc.expose.api.enable);
        message = "homelab.services.llama-cpp-agent.apiKeySecretName is required before exposing the API outside localhost.";
      }
    ];

    virtualisation = {
      docker.enable = true;

      oci-containers = lib.mkIf (!svc.dynamicStart.enable) {
        backend = lib.mkDefault "docker";

        containers."llama-cpp-agent" = {
          inherit (svc) autoStart image;

          ports = [
            "${svc.bindAddress}:${toString svc.upstream.port}:${toString svc.upstream.port}"
          ];

          volumes = [
            "${toString svc.modelDir}:/models:ro"
          ]
          ++ lib.optionals (apiKeyPath != null) [
            "${toString apiKeyPath}:/run/secrets/llama-cpp-agent-api-key:ro"
          ];

          cmd = serverArgs;

          environment = lib.optionalAttrs svc.gpu.enable {
            NVIDIA_VISIBLE_DEVICES = "all";
            NVIDIA_DRIVER_CAPABILITIES = "compute,utility";
          };

          extraOptions = [
            "--ipc=host"
          ]
          ++ lib.optionals svc.mlock [
            "--ulimit=memlock=-1:-1"
          ]
          ++ lib.optionals svc.gpu.enable gpuRunOptions;
        };
      };
    };

    systemd.services.llama-cpp-agent = lib.mkIf svc.dynamicStart.enable {
      description = "llama.cpp on-demand proxy for Qwen 3.6";
      after = [
        "docker.service"
        "network-online.target"
      ];
      wants = [
        "docker.service"
        "network-online.target"
      ];
      wantedBy = lib.optionals svc.autoStart [ "multi-user.target" ];
      path = [ pkgs.docker ];
      serviceConfig = {
        ExecStart = "${pkgs.llama-swap}/bin/llama-swap --config /etc/llama-cpp-agent/config.json --listen ${svc.bindAddress}:${toString svc.upstream.port}";
        Restart = "always";
        RestartSec = 5;
      };
    };

    environment.etc = lib.mkIf svc.dynamicStart.enable {
      "llama-cpp-agent/config.json".text = builtins.toJSON llamaSwapConfig;
    };

    hardware.nvidia-container-toolkit.enable = svc.gpu.enable;

    networking.firewall.allowedTCPPorts = lib.optionals svc.openFirewall [
      svc.upstream.port
    ];
  };
}
