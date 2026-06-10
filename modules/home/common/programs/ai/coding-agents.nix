{
  config,
  ...
}:
{
  sops.secrets.pi_legion_api_key = {
    sopsFile = config.custom.repoPath + "/secrets/server-legion/llama-cpp-agent.yaml";
    key = "llama_cpp_agent_api_key";
  };

  services.open-design = {
    enable = true;
    autoStart = true;
    webFrontend.enable = true;
  };

}
