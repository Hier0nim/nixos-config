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

  serverHost = if svc.runtime == "docker" then "0.0.0.0" else "127.0.0.1";
  serverPort = if svc.runtime == "docker" then "8080" else portMacro;

  enabledModels = lib.filterAttrs (_: model: model.enable) svc.models;
  downloadableModels = lib.filterAttrs (
    _: model: model.download.enable && model.url != null
  ) enabledModels;
  modelDownloadUnits = map (name: "llama-cpp-agent-model-${name}.service") (
    builtins.attrNames downloadableModels
  );
  downloadServices = lib.mapAttrs' (
    name: model: lib.nameValuePair "llama-cpp-agent-model-${name}" (mkDownloadUnit name model)
  ) downloadableModels;

  mkModelPath =
    model:
    if svc.runtime == "docker" then
      "/models/${model.file}"
    else
      "${toString svc.modelDir}/${model.file}";

  mkVerifyModelFunction =
    model:
    if model.sha256 == null then
      ''
        verify_model() {
          return 0
        }
      ''
    else
      ''
        verify_model() {
          ${pkgs.coreutils}/bin/printf '%s  %s\n' ${lib.escapeShellArg model.sha256} "$1" | ${pkgs.coreutils}/bin/sha256sum -c -
        }
      '';

  mkServerArgs =
    model:
    [
      "-m"
      (mkModelPath model)

      "-ngl"
      (toString model.gpuLayers)

      "-c"
      (toString model.contextSize)

      "--host"
      serverHost

      "--port"
      serverPort

      "--cache-type-k"
      model.cacheTypeK

      "--cache-type-v"
      model.cacheTypeV
    ]
    ++ lib.optionals (model.cpuMoeLayers != null) [
      "--n-cpu-moe"
      (toString model.cpuMoeLayers)
    ]
    ++ lib.optionals model.noMmap [
      "--no-mmap"
    ]
    ++ lib.optionals model.mlock [
      "--mlock"
    ]
    ++ lib.optionals (model.flashAttention != null) [
      "--flash-attn"
      model.flashAttention
    ]
    ++ lib.optionals model.jinja [
      "--jinja"
    ]
    ++ model.extraArgs;

  gpuRunOptions = if svc.gpu.useCdi then [ "--device=nvidia.com/gpu=all" ] else [ "--gpus=all" ];

  mkDockerRunCommand =
    model:
    lib.concatStringsSep " " (
      [
        "docker"
        "run"
        "--init"
        "--rm"
        "--name"
        modelIdMacro
        "--ipc=host"
        "--publish"
        "127.0.0.1:${portMacro}:8080"
        "--volume"
        "${toString svc.modelDir}:/models:ro"
      ]
      ++ lib.optionals (svc.workDir != null) [
        "--workdir"
        svc.workDir
      ]
      ++ lib.concatMap (volume: [
        "--volume"
        volume
      ]) svc.extraVolumes
      ++ lib.optionals svc.gpu.enable (
        [
          "--env"
          "NVIDIA_VISIBLE_DEVICES=all"
          "--env"
          "NVIDIA_DRIVER_CAPABILITIES=compute,utility"
        ]
        ++ gpuRunOptions
      )
      ++ lib.optionals model.mlock [
        "--ulimit"
        "memlock=-1:-1"
      ]
      ++ svc.extraRunOptions
      ++ [
        svc.image
      ]
      ++ svc.command
      ++ mkServerArgs model
    );

  mkNativeRunCommand =
    model:
    lib.concatStringsSep " " (
      [
        "${svc.package}/bin/llama-server"
      ]
      ++ mkServerArgs model
    );

  mkRunCommand =
    model: if svc.runtime == "docker" then mkDockerRunCommand model else mkNativeRunCommand model;
  mkDownloadUnit =
    name: model:
    let
      modelTarget = "${toString svc.modelDir}/${model.file}";
    in
    {
      description = "Download llama.cpp model ${name} for llama-cpp-agent";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail

        target=${lib.escapeShellArg modelTarget}
        url=${lib.escapeShellArg model.url}
        tmp="$target.part"

        ${mkVerifyModelFunction model}

        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"

        if [ -s "$target" ]; then
          verify_model "$target"
          exit 0
        fi

        ${pkgs.curl}/bin/curl \
          --location \
          --fail \
          --retry 5 \
          --retry-delay 10 \
          --continue-at - \
          --output "$tmp" \
          "$url"

        verify_model "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$target"
        ${pkgs.coreutils}/bin/chmod 0444 "$target"
      '';
    };

  llamaSwapConfig = {
    healthCheckTimeout = 600;
    models = lib.mapAttrs (
      _: model:
      {
        inherit (model) name;
        ttl = if model.ttl != null then model.ttl else svc.dynamicStart.idleStopMinutes * 60;
        cmd = mkRunCommand model;
      }
      // lib.optionalAttrs (svc.runtime == "docker") {
        cmdStop = "docker stop ${modelIdMacro}";
      }
    ) enabledModels;
  };
in
{
  config = lib.mkIf (cfg.enable && svc.enable) {
    assertions = [
      {
        assertion = enabledModels != { };
        message = "homelab.services.llama-cpp-agent.models must contain at least one enabled model.";
      }
      {
        assertion = svc.defaultModel == null || builtins.hasAttr svc.defaultModel enabledModels;
        message = "homelab.services.llama-cpp-agent.defaultModel must reference an enabled model.";
      }
      {
        assertion =
          apiKeyPath != null
          || (!svc.openFirewall && svc.bindAddress == "127.0.0.1" && !svc.expose.api.enable);
        message = "homelab.services.llama-cpp-agent.apiKeySecretName is required before exposing the API outside localhost.";
      }
      {
        assertion = !svc.expose.enable || svc.defaultModel != null;
        message = "homelab.services.llama-cpp-agent.defaultModel is required when browser chat exposure is enabled.";
      }
      {
        assertion =
          !svc.expose.enable || (svc.defaultModel != null && builtins.hasAttr svc.defaultModel enabledModels);
        message = "homelab.services.llama-cpp-agent.defaultModel must reference an enabled model when browser chat exposure is enabled.";
      }
      {
        assertion =
          svc.runtime != "docker"
          ||
            builtins.match ".*(^|[[:space:]])--publish[=[:space:]]0\\.0\\.0\\.0:.*" (
              lib.concatStringsSep " " svc.extraRunOptions
            ) == null;
        message = "homelab.services.llama-cpp-agent.extraRunOptions must not publish Docker model ports on 0.0.0.0.";
      }
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (name: model: [
        {
          assertion = builtins.match "[A-Za-z0-9._-]+" name != null;
          message = "homelab.services.llama-cpp-agent model id '${name}' may only contain letters, numbers, dots, underscores, and hyphens.";
        }
        {
          assertion = model.file != "";
          message = "homelab.services.llama-cpp-agent.models.${name}.file must not be empty.";
        }
        {
          assertion = !model.download.enable || model.url != null;
          message = "homelab.services.llama-cpp-agent.models.${name}.url must be set when download.enable is true.";
        }
        {
          assertion = model.contextSize > 0;
          message = "homelab.services.llama-cpp-agent.models.${name}.contextSize must be greater than 0.";
        }
        {
          assertion = model.gpuLayers >= 0;
          message = "homelab.services.llama-cpp-agent.models.${name}.gpuLayers must be greater than or equal to 0.";
        }
        {
          assertion = model.ttl == null || model.ttl >= 0;
          message = "homelab.services.llama-cpp-agent.models.${name}.ttl must be greater than or equal to 0.";
        }
      ]) enabledModels
    )
    ++ [
      {
        assertion = svc.dynamicStart.idleStopMinutes >= 0;
        message = "homelab.services.llama-cpp-agent.dynamicStart.idleStopMinutes must be greater than or equal to 0.";
      }
    ];

    virtualisation = {
      docker.enable = lib.mkIf (svc.runtime == "docker") true;
    };

    systemd.services = downloadServices // {
      llama-cpp-agent = {
        description = "llama.cpp on-demand proxy";
        after = [
          "network-online.target"
        ]
        ++ lib.optionals (svc.runtime == "docker") [ "docker.service" ]
        ++ modelDownloadUnits;
        wants = [
          "network-online.target"
        ]
        ++ lib.optionals (svc.runtime == "docker") [ "docker.service" ]
        ++ modelDownloadUnits;
        requires = modelDownloadUnits;
        wantedBy = lib.optionals (svc.autoStart || svc.expose.enable || svc.expose.api.enable) [
          "multi-user.target"
        ];
        path = lib.optionals (svc.runtime == "docker") [ pkgs.docker ];
        serviceConfig = {
          ExecStart = "${pkgs.llama-swap}/bin/llama-swap --config /etc/llama-cpp-agent/config.json --listen ${svc.bindAddress}:${toString svc.upstream.port}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    environment.etc = {
      "llama-cpp-agent/config.json".text = builtins.toJSON llamaSwapConfig;
    };

    hardware.nvidia-container-toolkit.enable = lib.mkIf (
      svc.gpu.enable && svc.runtime == "docker"
    ) true;

    networking.firewall.allowedTCPPorts = lib.optionals svc.openFirewall [
      svc.upstream.port
    ];
  };
}
