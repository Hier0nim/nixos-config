{ lib, types }:
{
  name,
  descriptionPrefix ? "llama.cpp",
}:
{
  name = lib.mkOption {
    type = types.str;
    default = name;
    description = "Display name for ${name}.";
  };

  file = lib.mkOption {
    type = types.str;
    default = "";
    description = "GGUF model filename for ${name}.";
  };

  url = lib.mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Optional URL used to download ${name}.";
  };

  sha256 = lib.mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Optional SHA256 checksum for the downloaded ${name} GGUF file.";
  };

  ttl = lib.mkOption {
    type = types.nullOr types.int;
    default = null;
    description = "Seconds before ${descriptionPrefix} unloads ${name}.";
  };

  contextSize = lib.mkOption {
    type = types.int;
    default = 8192;
    description = "Maximum llama.cpp context size in tokens for ${name}.";
  };

  batchSize = lib.mkOption {
    type = types.int;
    default = 4096;
    description = "llama.cpp logical batch size for ${name}.";
  };

  ubatchSize = lib.mkOption {
    type = types.int;
    default = 512;
    description = "llama.cpp physical batch size for ${name}.";
  };

  gpuLayers = lib.mkOption {
    type = types.int;
    default = 999;
    description = "Number of ${name} model layers to offload to GPU.";
  };

  cpuMoeLayers = lib.mkOption {
    type = types.nullOr types.int;
    default = 35;
    description = "Number of ${name} MoE layers to keep on CPU. Set to null to omit --n-cpu-moe.";
  };

  cacheTypeK = lib.mkOption {
    type = types.str;
    default = "q8_0";
    description = "llama.cpp KV cache type for ${name} K cache.";
  };

  cacheTypeV = lib.mkOption {
    type = types.str;
    default = "q8_0";
    description = "llama.cpp KV cache type for ${name} V cache.";
  };

  noMmap = lib.mkOption {
    type = types.bool;
    default = true;
    description = "Whether to pass --no-mmap for ${name}.";
  };

  mlock = lib.mkOption {
    type = types.bool;
    default = true;
    description = "Whether to pass --mlock for ${name}.";
  };

  flashAttention = lib.mkOption {
    type = types.nullOr (
      types.enum [
        "on"
        "off"
        "auto"
      ]
    );
    default = "auto";
    description = "Flash Attention mode for ${name}; null omits --flash-attn.";
  };

  temperature = lib.mkOption {
    type = types.float;
    default = 0.6;
    description = "Sampling temperature for ${name}.";
  };

  topP = lib.mkOption {
    type = types.float;
    default = 0.95;
    description = "Top-p sampling threshold for ${name}.";
  };

  topK = lib.mkOption {
    type = types.int;
    default = 20;
    description = "Top-k sampling threshold for ${name}.";
  };

  minP = lib.mkOption {
    type = types.float;
    default = 0.0;
    description = "Min-p sampling threshold for ${name}.";
  };

  presencePenalty = lib.mkOption {
    type = types.float;
    default = 0.0;
    description = "Presence penalty for ${name}.";
  };

  repeatPenalty = lib.mkOption {
    type = types.float;
    default = 1.0;
    description = "Repeat penalty for ${name}.";
  };

  jinja = lib.mkOption {
    type = types.bool;
    default = false;
    description = "Whether to pass --jinja for ${name}.";
  };

  extraArgs = lib.mkOption {
    type = types.listOf types.str;
    default = [ ];
    description = "Additional llama-server arguments appended for ${name}.";
  };
}
