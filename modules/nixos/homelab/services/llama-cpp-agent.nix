{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  svc = cfg.services."llama-cpp-agent";
  apiKeyPath =
    if svc.apiKeySecretName != null then config.sops.secrets.${svc.apiKeySecretName}.path else null;
in
{
  config = lib.mkIf (cfg.enable && svc.enable) {
    assertions = [
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
          !svc.expose.enable
          || (
            svc.defaultModel != null
            && builtins.hasAttr svc.defaultModel (lib.filterAttrs (_: model: model.enable) svc.models)
          );
        message = "homelab.services.llama-cpp-agent.defaultModel must reference an enabled model when browser chat exposure is enabled.";
      }
    ];

    services.llama-cpp-swap = {
      enable = true;
      inherit (svc)
        package
        openFirewall
        modelDir
        defaultModel
        models
        ;
      inherit (svc.upstream) port;
      inherit (svc.dynamicStart) idleStopMinutes;
      llamaSwapPackage = pkgs.llama-swap;
      listenAddress = svc.bindAddress;
    };
  };
}
