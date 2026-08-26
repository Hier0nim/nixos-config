{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  forgejoCfg = cfg.services.forgejo;
  actionsCfg = forgejoCfg.actions;
in
{
  options.homelab.services.forgejo.actions = {
    enable = lib.mkEnableOption "the native Forgejo Actions runner";
    tokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "forgejo_runner_token";
      description = "SOPS secret containing the Forgejo runner registration token.";
    };
    tokenSopsFile = lib.mkOption {
      type = lib.types.str;
      default = "secrets/server-legion/forgejo-runner.yaml";
      description = "Repository-relative SOPS file containing the registration token.";
    };
  };

  config = lib.mkIf (cfg.enable && forgejoCfg.enable && actionsCfg.enable) {
    users.groups.gitea-runner = { };
    users.users.gitea-runner = {
      isSystemUser = true;
      group = "gitea-runner";
      home = "/var/lib/gitea-runner";
      createHome = false;
    };

    nix.settings = {
      sandbox = true;
      sandbox-fallback = false;
    };

    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.global = {
        enable = true;
        name = "server-legion-forgejo-ci";
        url = "http://${forgejoCfg.upstream.host}:${toString forgejoCfg.upstream.port}";
        tokenFile = config.sops.templates."forgejo-runner-token.env".path;
        labels = [ "nix:host" ];
        hostPackages = [
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.curl
          pkgs.nodejs_24
          pkgs.nix
        ];
        settings = {
          runner = {
            capacity = 1;
            timeout = "3h";
          };
          cache.enabled = false;
        };
      };
    };

    systemd.services.gitea-runner-global = {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "gitea-runner";
        Group = "gitea-runner";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        RestrictSUIDSGID = true;
        UMask = "0077";
        ReadWritePaths = [ "/var/lib/gitea-runner" ];
        InaccessiblePaths = [ "/var/lib/homelab" ];
      };
    };

    assertions = [
      {
        assertion = config.nix.settings.sandbox or false;
        message = "The native Forgejo runner requires Nix sandboxing to remain enabled.";
      }
      {
        assertion = !(config.nix.settings.sandbox-fallback or false);
        message = "The native Forgejo runner requires nix.settings.sandbox-fallback = false.";
      }
    ];
  };
}
