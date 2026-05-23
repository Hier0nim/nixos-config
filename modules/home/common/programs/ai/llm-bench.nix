{
  hostName,
  lib,
  pkgs,
  systemConfig,
  ...
}:
let
  ai = import ./data.nix;

  llamaCfg =
    if hostName == "server-legion" then
      systemConfig.homelab.services."llama-cpp-agent"
    else
      systemConfig.services.llama-cpp-swap;

  qwenModel = llamaCfg.models.qwen;

  mkBenchScript = model: ''
    set -euo pipefail

    exec ${pkgs.llama-cpp.override { cudaSupport = true; }}/bin/llama-bench \
      -m ${lib.escapeShellArg "${llamaCfg.modelDir}/${model.file}"} \
      -ngl ${toString model.gpuLayers} \
      -ncmoe ${toString model.cpuMoeLayers} \
      -ctk ${lib.escapeShellArg model.cacheTypeK} \
      -ctv ${lib.escapeShellArg model.cacheTypeV} \
      -fa ${if model.flashAttention == "off" then "0" else "1"} \
      -mmp ${if model.noMmap then "0" else "1"} \
      "$@"
  '';

  mkBenchWrapper =
    {
      name,
      model,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.coreutils ];
      text = mkBenchScript model;
    };
in
{
  home.packages = [
    (mkBenchWrapper {
      inherit (ai.bench.qwen) name;
      model = qwenModel;
    })
  ];
}
