{
  config,
  pkgs,
  ...
}:
let
  ai = import ./data.nix;
  modelsJsonFormat = pkgs.formats.json { };
  modelsJson = {
    providers = {
      "${ai.api.local.providerId}" = {
        inherit (ai.api.local) baseUrl;
        api = "openai-completions";
        apiKey = ai.api.local.providerId;
        inherit (ai.api.local) compat;
        models = [
          {
            id = ai.api.local.modelId;
            name = ai.api.local.displayName;
            reasoning = false;
            input = [ "text" ];
            inherit (ai.api.local) contextWindow;
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

      "${ai.api.legion.providerId}" = {
        inherit (ai.api.legion) baseUrl;
        api = "openai-completions";
        apiKey = "!${pkgs.coreutils}/bin/cat ${config.sops.secrets.${ai.api.legion.apiKeySecret}.path}";
        inherit (ai.api.legion) authHeader compat;
        models = [
          {
            id = ai.api.legion.modelId;
            name = ai.api.legion.displayName;
            reasoning = false;
            input = [ "text" ];
            inherit (ai.api.legion) contextWindow;
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
in
{
  sops.secrets.pi_legion_api_key = {
    sopsFile = config.custom.repoPath + "/secrets/server-legion/llama-cpp-agent.yaml";
    key = "llama_cpp_agent_api_key";
  };

  home = {
    packages = with pkgs; [
      claude-code
      codex
      socat
    ];

    file.".pi/agent/models.json".source = modelsJsonFormat.generate "models.json" modelsJson;

    file.".pi/agent/models.json".text = builtins.toJSON {
      providers = {
        "${ai.api.local.providerId}" = {
          inherit (ai.api.local) baseUrl;
          api = "openai-completions";
          apiKey = ai.api.local.providerId;
          inherit (ai.api.local) compat;
          models = [
            {
              id = ai.api.local.modelId;
              name = ai.api.local.displayName;
              reasoning = false;
              input = [ "text" ];
              inherit (ai.api.local) contextWindow;
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

        "${ai.api.legion.providerId}" = {
          inherit (ai.api.legion) baseUrl;
          api = "openai-completions";
          apiKey = "!${pkgs.coreutils}/bin/cat ${config.sops.secrets.${ai.api.legion.apiKeySecret}.path}";
          inherit (ai.api.legion) authHeader compat;
          models = [
            {
              id = ai.api.legion.modelId;
              name = ai.api.legion.displayName;
              reasoning = false;
              input = [ "text" ];
              inherit (ai.api.legion) contextWindow;
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
  };
}
