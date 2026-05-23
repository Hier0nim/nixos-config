{
  api = {
    local = {
      providerId = "local-qwen";
      modelId = "qwen";
      baseUrl = "http://127.0.0.1:8080/v1";
      displayName = "Qwen 3.6 35B A3B (local)";
      contextWindow = 65536;
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
        maxTokensField = "max_tokens";
      };
    };

    legion = {
      providerId = "legion-qwen";
      modelId = "qwen-legion";
      baseUrl = "https://ai-api.pieczarkowo.me/v1";
      displayName = "Qwen 3.6 35B A3B (Legion)";
      contextWindow = 65536;
      apiKeySecret = "pi_legion_api_key";
      authHeader = true;
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
        maxTokensField = "max_tokens";
      };
    };
  };

  bench = {
    qwen = {
      name = "llama-bench-qwen";
      displayName = "Qwen 3.6 35B A3B";
    };
  };
}
