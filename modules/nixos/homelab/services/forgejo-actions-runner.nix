{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab;
  forgejoCfg = cfg.services.forgejo;
  runnerEnabled = cfg.enable && forgejoCfg.enable && forgejoCfg.actions.runner.enable;
  bridgeName = "br-forgejo-runner";
  tapName = "tap-fj-runner";
  hostAddress = "10.203.0.1";
  guestAddress = "10.203.0.2";
  storageDir = "/var/lib/microvms/forgejo-runner-phase-a";
  microvmStateDir = "${storageDir}/state";
  vmStateDir = "${microvmStateDir}/forgejo-runner";
  volumeImage = "${vmStateDir}/var.raw";
  iptables = "${pkgs.iptables}/bin/iptables";
  ip6tables = "${pkgs.iptables}/bin/ip6tables";
  caddyfile = pkgs.writeText "forgejo-runner-proxy.Caddyfile" ''
    {
      admin off
      auto_https off
    }

    http://${hostAddress}:18080 {
      @health path /healthz
      handle @health {
        rewrite * /api/healthz
        reverse_proxy 127.0.0.1:3000
      }
      respond "Not Found" 404
    }
  '';
in
{
  config = lib.mkMerge [
    {
      microvm.host.enable = runnerEnabled;
    }
    (lib.mkIf runnerEnabled {
      assertions = [
        {
          assertion = config.networking.firewall.enable;
          message = "Forgejo runner Phase-A requires the host firewall to protect ${bridgeName}.";
        }
        {
          assertion = config.networking.firewall.backend == "iptables";
          message = "Forgejo runner Phase-A only supports the current iptables firewall backend.";
        }
        {
          assertion = forgejoCfg.upstream.host == "127.0.0.1" && forgejoCfg.upstream.port == 3000;
          message = "Forgejo runner Phase-A requires Forgejo at 127.0.0.1:3000.";
        }
      ];

      networking.networkmanager.unmanaged = [
        "interface-name:${bridgeName}"
        "interface-name:${tapName}"
      ];

      networking.firewall = {
        extraCommands = ''
          while ${iptables} -D nixos-fw -i ${bridgeName} -s ${guestAddress} -d ${hostAddress} -p tcp --dport 18080 -j ACCEPT 2>/dev/null; do :; done
          while ${iptables} -D nixos-fw -i ${bridgeName} -j DROP 2>/dev/null; do :; done
          while ${ip6tables} -D nixos-fw -i ${bridgeName} -j DROP 2>/dev/null; do :; done
          ${iptables} -I nixos-fw 1 -i ${bridgeName} -j DROP
          ${iptables} -I nixos-fw 1 -i ${bridgeName} -s ${guestAddress} -d ${hostAddress} -p tcp --dport 18080 -j ACCEPT
          ${ip6tables} -I nixos-fw 1 -i ${bridgeName} -j DROP
        '';
        extraStopCommands = ''
          while ${iptables} -D nixos-fw -i ${bridgeName} -s ${guestAddress} -d ${hostAddress} -p tcp --dport 18080 -j ACCEPT 2>/dev/null; do :; done
          while ${iptables} -D nixos-fw -i ${bridgeName} -j DROP 2>/dev/null; do :; done
          while ${ip6tables} -D nixos-fw -i ${bridgeName} -j DROP 2>/dev/null; do :; done
        '';
      };

      security.wrappers.qemu-bridge-helper.enable = false;

      microvm = {
        stateDir = microvmStateDir;
        vms.forgejo-runner = {
          autostart = true;
          config = {
            microvm = {
              hypervisor = "qemu";
              storeOnDisk = true;
              shares = [ ];
              interfaces = [
                {
                  type = "tap";
                  id = tapName;
                  mac = "02:00:00:30:00:02";
                }
              ];
              volumes = [
                {
                  image = volumeImage;
                  label = "forgejo-runner-var";
                  mountPoint = "/var";
                  size = 4096;
                  fsType = "ext4";
                  autoCreate = false;
                }
              ];
              binScripts.tap-up = lib.mkAfter ''
                ${pkgs.iproute2}/bin/ip link set dev ${tapName} master ${bridgeName}
              '';
            };

            networking = {
              enableIPv6 = false;
              nameservers = [ ];
              defaultGateway = null;
              defaultGateway6 = null;
              useDHCP = false;
              useNetworkd = true;
            };

            systemd = {
              network = {
                networks."10-forgejo-runner" = {
                  matchConfig.MACAddress = "02:00:00:30:00:02";
                  address = [ "${guestAddress}/30" ];
                  networkConfig = {
                    ConfigureWithoutCarrier = true;
                    DHCP = "no";
                    IPv6AcceptRA = false;
                    LinkLocalAddressing = "no";
                  };
                };
              };
              services.forgejo-runner-health = {
                serviceConfig = {
                  Type = "oneshot";
                  PrivateTmp = true;
                  ProtectHome = true;
                  ProtectSystem = "strict";
                };
                script = ''
                  ${pkgs.curl}/bin/curl --fail --silent --show-error --connect-timeout 5 http://${hostAddress}:18080/healthz >/dev/null
                '';
              };
              timers.forgejo-runner-health = {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnBootSec = "1min";
                  OnUnitActiveSec = "5min";
                  Unit = "forgejo-runner-health.service";
                };
              };
            };
          };
        };
      };

      users.groups.forgejo-runner-proxy = { };
      users.users.forgejo-runner-proxy = {
        isSystemUser = true;
        group = "forgejo-runner-proxy";
      };

      systemd = {
        network = {
          enable = true;
          netdevs."20-${bridgeName}" = {
            netdevConfig = {
              Kind = "bridge";
              Name = bridgeName;
            };
          };
          networks."20-${bridgeName}" = {
            matchConfig.Name = bridgeName;
            address = [ "${hostAddress}/30" ];
            linkConfig.RequiredForOnline = false;
            networkConfig = {
              ConfigureWithoutCarrier = true;
              DHCP = "no";
              IPv6AcceptRA = false;
              LinkLocalAddressing = "no";
            };
          };
        };
        services = {
          forgejo-runner-phase-a-preflight = {
            description = "Validate Forgejo runner Phase-A isolation";
            after = [
              "firewall.service"
              "systemd-networkd.service"
            ];
            before = [
              "forgejo-runner-phase-a-storage.service"
              "forgejo-runner-proxy.service"
              "microvm-tap-interfaces@forgejo-runner.service"
            ];
            serviceConfig.Type = "oneshot";
            path = [
              pkgs.coreutils
              pkgs.gawk
              pkgs.iproute2
              pkgs.iptables
            ];
            script = ''
              set -euo pipefail
              timeout 30s ${pkgs.bash}/bin/bash -c '
                until ip link show dev ${bridgeName} >/dev/null 2>&1 &&
                  test "$(ip -4 -o addr show dev ${bridgeName} | awk "{ print \$4 }")" = "${hostAddress}/30"; do
                  sleep 1
                done
              '
              test "$(ip -4 -o addr show dev ${bridgeName} | awk '{ print $4 }')" = "${hostAddress}/30"
              test "$(ip -4 -o addr show | awk '$4 ~ /^10\\.203\\.0\\.1\// { print $2 }')" = "${bridgeName}"
              test -z "$(ip -4 -o addr show | awk '$4 ~ /^10\\.203\\.0\\.2\// { print $2 }')"
              test "$(ip -4 route show table all 10.203.0.0/30 | awk '{ print $1, $3 }')" = "10.203.0.0/30 ${bridgeName}"
              ${iptables} -C nixos-fw -i ${bridgeName} -s ${guestAddress} -d ${hostAddress} -p tcp --dport 18080 -j ACCEPT
              ${iptables} -C nixos-fw -i ${bridgeName} -j DROP
              ${ip6tables} -C nixos-fw -i ${bridgeName} -j DROP
              rules="$(${iptables} -S nixos-fw)"
              accept_line="$(printf '%s\n' "$rules" | nl -ba | awk '/-A nixos-fw -i ${bridgeName} -s ${guestAddress}\/32 -d ${hostAddress}\/32 -p tcp -m tcp --dport 18080 -j ACCEPT$/ { print $1 }')"
              drop_line="$(printf '%s\n' "$rules" | nl -ba | awk '/-A nixos-fw -i ${bridgeName} -j DROP$/ { print $1 }')"
              test -n "$accept_line"
              test -n "$drop_line"
              test "$accept_line" -lt "$drop_line"
            '';
          };

          forgejo-runner-phase-a-storage = {
            description = "Provision Forgejo runner Phase-A Btrfs storage";
            requires = [ "forgejo-runner-phase-a-preflight.service" ];
            after = [ "forgejo-runner-phase-a-preflight.service" ];
            before = [ "install-microvm-forgejo-runner.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            path = [
              pkgs.btrfs-progs
              pkgs.coreutils
              pkgs.e2fsprogs
              pkgs.util-linux
            ];
            script = ''
              set -euo pipefail
              test "$(findmnt -n -o FSTYPE --target /var)" = btrfs
              if [ -e ${storageDir} ]; then
                btrfs subvolume show ${storageDir} >/dev/null
              else
                install -d -m 0755 /var/lib/microvms
                btrfs subvolume create ${storageDir}
              fi
              btrfs quota enable /var
              btrfs qgroup limit 5G ${storageDir}
              install -d -o microvm -g kvm -m 0750 ${vmStateDir}
              if [ -e ${volumeImage} ] || [ -L ${volumeImage} ]; then
                test -f ${volumeImage}
                test ! -L ${volumeImage}
              else
                for staleImage in "${vmStateDir}"/.var.raw.*; do
                  [ -e "$staleImage" ] || [ -L "$staleImage" ] || continue
                  case "$staleImage" in
                    "${vmStateDir}"/.var.raw.[[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]]) ;;
                    *) exit 1 ;;
                  esac
                  test -f "$staleImage"
                  test ! -L "$staleImage"
                  test "$(stat -c %u "$staleImage")" -eq 0
                  rm -f -- "$staleImage"
                done
                test "$(df --output=avail -B1 /var | tail -n 1 | tr -d ' ')" -ge 42949672960
                temporaryImage="$(mktemp "${vmStateDir}/.var.raw.XXXXXX")"
                trap 'rm -f "$temporaryImage"' EXIT
                chattr +C "$temporaryImage"
                fallocate -l 4G "$temporaryImage"
                mkfs.ext4 -F -L forgejo-runner-var "$temporaryImage"
                test "$(stat -c %s "$temporaryImage")" -eq 4294967296
                case "$(lsattr -d "$temporaryImage")" in *C*) ;; *) exit 1 ;; esac
                test "$(blkid -s TYPE -o value "$temporaryImage")" = ext4
                test "$(blkid -s LABEL -o value "$temporaryImage")" = forgejo-runner-var
                mv "$temporaryImage" ${volumeImage}
                trap - EXIT
              fi
              test -f ${volumeImage}
              test ! -L ${volumeImage}
              test "$(stat -c %s ${volumeImage})" -eq 4294967296
              case "$(lsattr -d ${volumeImage})" in *C*) ;; *) exit 1 ;; esac
              test "$(blkid -s TYPE -o value ${volumeImage})" = ext4
              test "$(blkid -s LABEL -o value ${volumeImage})" = forgejo-runner-var
              chown microvm:kvm ${volumeImage}
              chmod 0600 ${volumeImage}
              btrfs subvolume show ${storageDir} >/dev/null
            '';
          };

          "install-microvm-forgejo-runner" = {
            requires = [ "forgejo-runner-phase-a-storage.service" ];
            after = [ "forgejo-runner-phase-a-storage.service" ];
          };

          "microvm-tap-interfaces@forgejo-runner" = {
            requires = [ "forgejo-runner-phase-a-preflight.service" ];
            after = [ "forgejo-runner-phase-a-preflight.service" ];
          };

          forgejo-runner-proxy = {
            description = "Private Forgejo runner health proxy";
            requires = [ "forgejo-runner-phase-a-preflight.service" ];
            after = [
              "forgejo-runner-phase-a-preflight.service"
              "forgejo.service"
            ];
            wantedBy = [ "multi-user.target" ];
            environment = {
              XDG_CACHE_HOME = "/var/cache/forgejo-runner-proxy";
              XDG_CONFIG_HOME = "/var/lib/forgejo-runner-proxy";
              XDG_DATA_HOME = "/var/lib/forgejo-runner-proxy";
            };
            serviceConfig = {
              User = "forgejo-runner-proxy";
              Group = "forgejo-runner-proxy";
              ExecStart = "${pkgs.caddy}/bin/caddy run --config ${caddyfile} --adapter caddyfile";
              Restart = "on-failure";
              RuntimeDirectory = "forgejo-runner-proxy";
              StateDirectory = "forgejo-runner-proxy";
              CacheDirectory = "forgejo-runner-proxy";
              UMask = "0077";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ProtectControlGroups = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_UNIX"
              ];
              IPAddressDeny = "any";
              IPAddressAllow = [
                "127.0.0.0/8"
                "${guestAddress}/32"
              ];
            };
          };
        };
      };
    })
  ];
}
