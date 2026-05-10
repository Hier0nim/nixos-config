{
  inputs,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      claude-code
      codex
      inputs.serena.packages.${pkgs.stdenv.hostPlatform.system}.serena
      pi-coding-agent
    ];

    file.".pi/agent/settings.json".text = builtins.toJSON {
      defaultProvider = "local-qwen";
      defaultModel = "qwen";
    };

    file.".pi/agent/models.json".text = builtins.toJSON {
      providers."local-qwen" = {
        baseUrl = "http://127.0.0.1:8080/v1";
        api = "openai-completions";
        apiKey = "local-qwen";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
          maxTokensField = "max_tokens";
        };
        models = [
          {
            id = "qwen";
            name = "Qwen 3.6 35B A3B (local)";
            reasoning = false;
            input = [ "text" ];
            contextWindow = 98304;
            maxTokens = 16384;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
          }
        ];
      };
    };
  };
}
