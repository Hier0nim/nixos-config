{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom.services.localLlama;
in
{
  options.custom.services.localLlama.enable =
    lib.mkEnableOption "local llama.cpp inference with default Qwen model";

  config = lib.mkIf cfg.enable {
    services.llama-cpp-swap = {
      enable = true;
      package = pkgs.llama-cpp.override { cudaSupport = true; };
      listenAddress = "127.0.0.1";
      port = 8080;
      openFirewall = false;
      modelDir = "/var/lib/llama-cpp/models";
      defaultModel = "qwen";
      idleStopMinutes = 5;

      models =
        let
          qwenModel = {
            name = "Qwen 3.6 35B A3B";
            file = "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf";
            url = "https://huggingface.co/bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf?download=true";
            sha256 = "6f5c72e2cde7fb0a1584cc009cdb4513f26733740369d3e2df0e7d7247112d05";

            gpuLayers = 99;
            cpuMoeLayers = 32;
            batchSize = 4096;
            ubatchSize = 512;
            cacheTypeK = "q8_0";
            cacheTypeV = "q8_0";
            temperature = 0.6;
            topP = 0.95;
            topK = 20;
            minP = 0.0;
            presencePenalty = 0.0;
            repeatPenalty = 1.0;
            jinja = true;
            extraArgs = [
              "--parallel"
              "1"
            ];
          };
        in
        {
          qwen = qwenModel // {
            contextSize = 131072;
          };
        };
    };
  };
}
