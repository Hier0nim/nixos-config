{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.services.llama-cpp-swap;
  settingsFormat = pkgs.formats.yaml { };
  portMacro = "$" + "{PORT}";
  llamaCppModel = import ../../shared/llama-cpp-model.nix {
    inherit lib;
    inherit (lib) types;
  };

  enabledModels = lib.filterAttrs (_: model: model.enable) cfg.models;
  downloadableModels = lib.filterAttrs (
    _: model: model.download.enable && model.url != null
  ) enabledModels;
  modelDownloadUnits = map (name: "llama-cpp-swap-model-${name}.service") (
    builtins.attrNames downloadableModels
  );

  mkModelPath = model: "${toString cfg.modelDir}/${model.file}";

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

  mkDownloadUnit =
    name: model:
    let
      modelTarget = "${toString cfg.modelDir}/${model.file}";
    in
    {
      description = "Download llama.cpp model ${name} for llama-cpp-swap";
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

  downloadServices = lib.mapAttrs' (
    name: model: lib.nameValuePair "llama-cpp-swap-model-${name}" (mkDownloadUnit name model)
  ) downloadableModels;

  mkServerArgs =
    model:
    [
      "-m"
      (mkModelPath model)
      "-ngl"
      (toString model.gpuLayers)
      "-c"
      (toString model.contextSize)
      "--batch-size"
      (toString model.batchSize)
      "--ubatch-size"
      (toString model.ubatchSize)
      "--host"
      "127.0.0.1"
      "--port"
      portMacro
      "--cache-type-k"
      model.cacheTypeK
      "--cache-type-v"
      model.cacheTypeV
      "--temp"
      (toString model.temperature)
      "--top-p"
      (toString model.topP)
      "--top-k"
      (toString model.topK)
      "--min-p"
      (toString model.minP)
      "--presence-penalty"
      (toString model.presencePenalty)
      "--repeat-penalty"
      (toString model.repeatPenalty)
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

  mkRunCommand =
    model: lib.escapeShellArgs ([ "${cfg.package}/bin/llama-server" ] ++ mkServerArgs model);

  llamaSwapSettings = cfg.settings // {
    inherit (cfg) healthCheckTimeout;
    models =
      (cfg.settings.models or { })
      // lib.mapAttrs (
        _: model:
        {
          inherit (model) name;
          ttl = if model.ttl != null then model.ttl else cfg.idleStopMinutes * 60;
          cmd = mkRunCommand model;
        }
        // lib.optionalAttrs (model.aliases != [ ]) {
          inherit (model) aliases;
        }
      ) enabledModels;
  };
  llamaSwapConfigFile = settingsFormat.generate "llama-cpp-swap.yaml" llamaSwapSettings;
in
{
  options.services.llama-cpp-swap = {
    enable = lib.mkEnableOption "llama.cpp on-demand model serving through llama-swap";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-cpp-turboquant or (pkgs.llama-cpp.override { cudaSupport = true; });
      description = "llama.cpp package used for llama-server model processes.";
    };

    llamaSwapPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-swap;
      description = "llama-swap package used for the always-on proxy daemon.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address that llama-swap listens on when supported by nixpkgs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port that llama-swap listens on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the llama-swap port in the firewall.";
    };

    modelDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/llama-cpp/models";
      description = "Directory containing GGUF model files.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default model id used by integrations such as browser redirects.";
    };

    idleStopMinutes = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Minutes of inactivity before llama-swap unloads a model. Set to 0 to keep it loaded.";
    };

    healthCheckTimeout = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "llama-swap health check timeout in seconds.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional native services.llama-swap.settings merged with generated model settings.";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Expose ${name} through llama-swap.";
              };

              download.enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Download ${name} into modelDir before starting llama-swap.";
              };

              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Display name for ${name}.";
              };

              aliases = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Additional llama-swap aliases for ${name}.";
              };
            }
            // llamaCppModel {
              inherit name;
              descriptionPrefix = "llama-swap";
            };
          }
        )
      );
      default = { };
      description = "llama-swap models keyed by API model id.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = enabledModels != { };
        message = "services.llama-cpp-swap.models must contain at least one enabled model.";
      }
      {
        assertion = cfg.defaultModel == null || builtins.hasAttr cfg.defaultModel enabledModels;
        message = "services.llama-cpp-swap.defaultModel must reference an enabled model.";
      }
      {
        assertion = cfg.idleStopMinutes >= 0;
        message = "services.llama-cpp-swap.idleStopMinutes must be greater than or equal to 0.";
      }
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (name: model: [
        {
          assertion = builtins.match "[A-Za-z0-9._-]+" name != null;
          message = "services.llama-cpp-swap model id '${name}' may only contain letters, numbers, dots, underscores, and hyphens.";
        }
        {
          assertion = model.file != "";
          message = "services.llama-cpp-swap.models.${name}.file must not be empty.";
        }
        {
          assertion = !model.download.enable || model.url != null;
          message = "services.llama-cpp-swap.models.${name}.url must be set when download.enable is true.";
        }
        {
          assertion = model.contextSize > 0;
          message = "services.llama-cpp-swap.models.${name}.contextSize must be greater than 0.";
        }
        {
          assertion = model.gpuLayers >= 0;
          message = "services.llama-cpp-swap.models.${name}.gpuLayers must be greater than or equal to 0.";
        }
        {
          assertion = model.ttl == null || model.ttl >= 0;
          message = "services.llama-cpp-swap.models.${name}.ttl must be greater than or equal to 0.";
        }
      ]) enabledModels
    );

    services.llama-swap = {
      enable = true;
      package = cfg.llamaSwapPackage;
      inherit (cfg) port openFirewall;
      settings = llamaSwapSettings;
    }
    // lib.optionalAttrs (options.services.llama-swap ? listenAddress) {
      inherit (cfg) listenAddress;
    };

    systemd.services = downloadServices // {
      llama-swap =
        lib.recursiveUpdate
          {
            after = [ "network-online.target" ] ++ modelDownloadUnits;
            wants = [ "network-online.target" ] ++ modelDownloadUnits;
            requires = modelDownloadUnits;
            serviceConfig = {
              ExecStartPre = [
                "+${pkgs.runtimeShell} -c '${pkgs.coreutils}/bin/chmod a+rw /dev/nvidia-caps/nvidia-cap* 2>/dev/null || true'"
              ];
              PrivateUsers = lib.mkForce false;
              SupplementaryGroups = [
                "render"
                "video"
              ];
            };
          }
          (
            lib.optionalAttrs (!(options.services.llama-swap ? listenAddress)) {
              serviceConfig = {
                ExecStart = lib.mkForce "${lib.getExe cfg.llamaSwapPackage} --listen ${cfg.listenAddress}:${toString cfg.port} --config ${llamaSwapConfigFile}";
              };
            }
          );
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.modelDir} 0755 root root - -"
      "Z ${cfg.modelDir} 0755 root root - -"
      "z /dev/nvidia-caps/nvidia-cap* 0666 root root - -"
    ];
  };
}
