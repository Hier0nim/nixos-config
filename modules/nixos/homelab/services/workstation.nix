{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.homelab;
  ws = cfg.workstation;

  enabledApps = lib.filterAttrs (_name: app: app.enable) ws.apps;

  appExposedPort = app: if app.exposedPort == 0 then app.port else app.exposedPort;

  homeProfile = lib.custom.relativeToRoot "users/hieronim/workstation.nix";
  homeModules = lib.custom.relativeToRoot "modules/home";

  mkAppProxyService =
    name: app:
    lib.nameValuePair "workstation-app-${name}" {
      description = "Expose workstation localhost app ${name} on the container private network";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = ''
          ${pkgs.socat}/bin/socat \
            TCP-LISTEN:${toString (appExposedPort app)},bind=${ws.network.localAddress},fork,reuseaddr \
            TCP:127.0.0.1:${toString app.port}
        '';
        Restart = "always";
        RestartSec = "2s";
        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

  mkAppVhost =
    name: app:
    let
      fqdn = "${app.subdomain}.${cfg.domain}";
      upstream = "http://${ws.network.localAddress}:${toString (appExposedPort app)}";
      authImport =
        lib.optionalString (app.authGroup != null)
          "import ${config.sops.templates."caddy-basic-auth-${app.authGroup}".path}";
      reverseProxy =
        if app.reverseProxyExtraConfig == "" then
          "reverse_proxy ${upstream}"
        else
          ''
            reverse_proxy ${upstream} {
              ${app.reverseProxyExtraConfig}
            }
          '';
      baseHandle = ''
        ${authImport}
        ${reverseProxy}
      '';
      cidrConfig = lib.optionalString (app.allowedCIDRs != [ ]) ''
        @allowed remote_ip ${lib.concatStringsSep " " app.allowedCIDRs}
        handle @allowed {
          ${baseHandle}
        }

        respond 404
      '';
    in
    lib.nameValuePair fqdn {
      extraConfig = if app.allowedCIDRs == [ ] then baseHandle else cidrConfig;
    };
in
{
  config = lib.mkIf (cfg.enable && ws.enable) {
    assertions = [
      {
        assertion = ws.apps == { } || cfg.proxy.enable;
        message = "homelab.workstation.apps requires homelab.proxy.enable = true.";
      }
      {
        assertion = lib.all (app: app.authGroup == null || builtins.hasAttr app.authGroup cfg.auth.groups) (
          lib.attrValues enabledApps
        );
        message = "Every workstation app authGroup must exist in homelab.auth.groups, or be null.";
      }
    ];

    containers.workstation = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = ws.network.hostAddress;
      localAddress = ws.network.localAddress;
      forwardPorts = lib.optional ws.ssh.enable {
        protocol = "tcp";
        hostPort = ws.ssh.hostPort;
        containerPort = 22;
      };
      bindMounts."/var/lib/sops-nix" = {
        hostPath = "/var/lib/sops-nix";
        isReadOnly = true;
      };

      config =
        {
          lib,
          pkgs,
          ...
        }:
        {
          imports = [
            inputs.home-manager.nixosModules.default
          ];

          networking = {
            hostName = "workstation";
            nameservers = ws.network.nameservers;
            firewall = {
              enable = true;
              allowedTCPPorts = lib.optional ws.ssh.enable 22 ++ map appExposedPort (lib.attrValues enabledApps);
            };
          };

          services.openssh = {
            enable = ws.ssh.enable;
            settings = {
              PermitRootLogin = "no";
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
              X11Forwarding = false;
              AllowUsers = [ ws.user ];
            };
          };

          users = {
            mutableUsers = false;
            groups.sops.gid = 984;
            users = {
              root.openssh.authorizedKeys.keys = cfg.ssh.authorizedKeys;

              ${ws.user} = {
                isNormalUser = true;
                uid = 1000;
                home = "/home/${ws.user}";
                shell = pkgs.nushell;
                extraGroups = [ "sops" ];
                openssh.authorizedKeys.keys = cfg.ssh.authorizedKeys;
              };
            };
          };

          nix = {
            # Add flake inputs as registry entries
            registry = lib.mapAttrs (_: value: { flake = value; }) (
              lib.filterAttrs (_: value: value ? _type && value._type == "flake") inputs
            );

            # Add registry to legacy NIX_PATH for comma/nix-shell
            nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

            settings = {
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              trusted-users = [ ws.user ];
            };
          };

          environment.systemPackages = with pkgs; [
            curl
            git
            socat
          ];

          systemd.services = lib.mapAttrs' mkAppProxyService enabledApps;

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            sharedModules = [
              homeModules
              inputs.open-design.homeManagerModules.default
              inputs.sops-nix.homeManagerModules.sops
              {
                programs.home-manager.enable = true;
                sops.age.keyFile = "/var/lib/sops-nix/key.txt";
              }
            ];
            extraSpecialArgs = {
              inherit inputs self;
              hostName = "workstation";
            };
            users.${ws.user}.imports = [
              homeProfile
            ];
          };

          system.stateVersion = "25.05";
        };
    };

    networking.firewall.allowedTCPPorts = lib.optional ws.ssh.openFirewall ws.ssh.hostPort;

    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-workstation" ];
      externalInterface = ws.network.externalInterface;
    };

    systemd.services."container@workstation".serviceConfig = {
      MemoryMax = ws.resources.memoryMax;
      CPUQuota = ws.resources.cpuQuota;
      TasksMax = 8192;
    };

    services.caddy.virtualHosts = lib.mkIf (cfg.proxy.enable && enabledApps != { }) (
      lib.mapAttrs' mkAppVhost enabledApps
    );
  };
}
