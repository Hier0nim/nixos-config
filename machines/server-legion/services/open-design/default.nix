{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  runtime = import ./image.nix {
    inherit pkgs;
    builder = self.inputs.nix2container.packages.${pkgs.stdenv.hostPlatform.system}.nix2container;
  };
  # Pi refreshes subscription credentials here.
  stateDir = "/var/lib/open-design";
  user = "${toString runtime.uid}:${toString runtime.gid}";
  # Docker rewrites loopback destinations before the OUTPUT filter.
  localGuardHooks = [
    "-p tcp -m conntrack --ctdir ORIGINAL --ctorigdst 127.0.0.1 --ctorigdstport 7456 -j open-design-local"
    "-o docker0 -p tcp --dport 7456 -j open-design-local"
  ];
  # name is the host command; command runs as the container user.
  helper =
    name: command:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.docker
        pkgs.coreutils
      ];
      text = ''
        if [ "$(id -u)" -ne 0 ]; then
          echo "Run ${name} through sudo on Legion" >&2
          exit 1
        fi
        if [ "$(docker inspect --format '{{.State.Running}}' open-design 2>/dev/null)" != true ]; then
          echo "OpenDesign container is not running" >&2
          exit 1
        fi
        tty=()
        if [ -t 0 ] && [ -t 1 ]; then tty=(-t); fi
        exec docker exec -i "''${tty[@]}" --user ${user} --workdir /state open-design ${command} "$@"
      '';
    };
in
{
  options.services.open-design.enable = lib.mkEnableOption "the private OpenDesign and Pi environment";

  config = lib.mkIf config.services.open-design.enable {
    assertions = [
      {
        assertion = lib.all (account: account.uid != runtime.uid) (
          builtins.attrValues (builtins.removeAttrs config.users.users [ "open-design" ])
        );
        message = "OpenDesign's UID is already assigned to another declared host account.";
      }
      {
        assertion = lib.all (group: group.gid != runtime.gid) (
          builtins.attrValues (builtins.removeAttrs config.users.groups [ "open-design" ])
        );
        message = "OpenDesign's GID is already assigned to another declared host group.";
      }
      {
        assertion = config.virtualisation.oci-containers.backend == "docker";
        message = "OpenDesign requires Legion's existing Docker backend.";
      }
      {
        assertion =
          (config.virtualisation.docker.daemon.settings.bridge or "docker0") == "docker0"
          && !(config.virtualisation.docker.daemon.settings.ipv6 or false);
        message = "OpenDesign's local guard requires Legion's IPv4 default docker0 bridge.";
      }
      {
        assertion =
          config.services.homelabIngress.enable
          && config.services.homelabIngress.services.design.auth == "proxy"
          && config.services.homelabIngress.services.design.group == "household"
          && !config.services.homelabIngress.services.design.integrationApiBypass;
        message = "OpenDesign's daemon must remain behind the household Authelia proxy gate.";
      }
      {
        assertion =
          config.virtualisation.oci-containers.containers.open-design.ports == [ "127.0.0.1:7456:7456" ];
        message = "OpenDesign must publish only host loopback port 7456, never CDP.";
      }
    ];
    users.groups.open-design.gid = runtime.gid;
    users.users.open-design = {
      inherit (runtime) uid;
      group = "open-design";
      isSystemUser = true;
      home = stateDir;
    };
    virtualisation.oci-containers.containers.open-design = {
      image = "${runtime.image.imageName}:${runtime.image.imageTag}";
      inherit user;
      networks = [ "bridge" ];
      pull = "never";
      ports = [ "127.0.0.1:7456:7456" ];
      volumes = [ "${stateDir}:/state" ];
      environment = runtime.environment // {
        TZ = config.time.timeZone;
      };
      log-driver = "local";
      extraOptions = [
        "--read-only"
        "--cap-drop=ALL"
        "--security-opt=no-new-privileges:true"
        "--memory=4g"
        "--cpus=2"
        "--pids-limit=1024"
        "--shm-size=512m"
        "--tmpfs=/tmp:rw,nosuid,nodev,noexec,size=1g,mode=1777"
        "--stop-timeout=45"
        "--log-opt=max-size=4m"
        "--log-opt=max-file=2"
      ];
    };
    systemd = {
      tmpfiles.rules = [ "d ${stateDir} 0700 open-design open-design - -" ];
      services = {
        docker-open-design = {
          after = [
            "systemd-tmpfiles-setup.service"
            "open-design-local-guard.service"
          ];
          requires = [ "open-design-local-guard.service" ];
          # Docker's simple unit starts before the container exists.
          postStart = ''
            for attempt in $(seq 1 60); do
              if ${pkgs.docker}/bin/docker inspect --format '{{.State.Running}}' open-design 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx true; then
                exec ${pkgs.docker}/bin/docker exec --user ${user} open-design /bin/node /etc/open-design/configure.mjs
              fi
              sleep 1
            done
            echo 'OpenDesign container did not start' >&2
            exit 1
          '';
          serviceConfig = {
            # Content-derived tags let restarts reuse an already loaded image.
            ExecStartPre = lib.mkBefore [
              (pkgs.writeShellScript "open-design-copy-to-docker-daemon" ''
                if ! ${pkgs.docker}/bin/docker image inspect ${runtime.image.imageName}:${runtime.image.imageTag} >/dev/null 2>&1; then
                  exec ${runtime.image.copyToDockerDaemon}/bin/copy-to-docker-daemon
                fi
              '')
            ];
            Restart = "on-failure";
            RestartSec = "15s";
            TimeoutStartSec = lib.mkForce "5min";
            TimeoutStopSec = lib.mkForce "60s";
            UMask = "0077";
            # Keep logs in Docker rather than duplicating them in the journal.
            StandardOutput = "null";
            StandardError = "journal";
            LogRateLimitIntervalSec = "30s";
            LogRateLimitBurst = 50;
          };
        };
        # Remove the chain when a rollback disables the service.
        open-design-local-guard = {
          description = "Restrict the OpenDesign backend to root and Caddy";
          after = [
            "firewall.service"
            "docker.service"
          ];
          before = [ "docker-open-design.service" ];
          path = [ pkgs.iptables ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            iptables -N open-design-local 2>/dev/null || true
            iptables -F open-design-local
            iptables -A open-design-local -m owner --uid-owner 0 -j RETURN
            iptables -A open-design-local -m owner --uid-owner caddy -j RETURN
            iptables -A open-design-local -p tcp -j REJECT --reject-with tcp-reset
            ${lib.concatMapStringsSep "\n" (hook: ''
              iptables -C OUTPUT ${hook} 2>/dev/null || iptables -I OUTPUT 1 ${hook}
            '') localGuardHooks}
          '';
          preStop = ''
            ${lib.concatMapStringsSep "\n" (hook: ''
              while iptables -D OUTPUT ${hook} 2>/dev/null; do :; done
            '') localGuardHooks}
            iptables -F open-design-local 2>/dev/null || true
            iptables -X open-design-local 2>/dev/null || true
          '';
        };
      };
    };
    services.homelabIngress.services.design = {
      upstream = "http://127.0.0.1:7456";
      transport = "direct";
      auth = "proxy";
      group = "household";
      integrationApiBypass = false;
    };
    environment.systemPackages = [
      (helper "open-design-pi" "/bin/pi")
      (helper "open-design-doctor" "/bin/node /etc/open-design/doctor.mjs")
    ];
  };
}
