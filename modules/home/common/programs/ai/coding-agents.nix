{
  config,
  lib,
  ...
}:
{
  options.custom.services.codingAgents.enable =
    lib.mkEnableOption "AI coding agents (sops secret + open-design service)";

  config = lib.mkIf config.custom.services.codingAgents.enable {
    sops.secrets.pi_legion_api_key = lib.mkIf (config.custom.hostName == "server-legion") {
      sopsFile = config.custom.repoPath + "/secrets/server-legion/llama-cpp-agent.yaml";
      key = "llama_cpp_agent_api_key";
    };

    services.open-design = {
      enable = true;
      autoStart = true;
      webFrontend.enable = true;
    };
  };
}
