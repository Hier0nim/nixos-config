{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  ipv4OctetPattern = "(0|[1-9][0-9]{0,2})";
  ipv4AddressPattern = "${ipv4OctetPattern}(\\.${ipv4OctetPattern}){3}";
in
{
  options.homelab.services.forgejo.actions = {
    images = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            archive = mkOption {
              type = types.package;
              description = "Digest-pinned OCI image archive copied into runner VMs.";
            };
            reference = mkOption {
              type = types.str;
              description = "Docker image reference produced by loading the archive.";
            };
            nixSeedEpoch = mkOption {
              type = types.strMatching "[1-9][0-9]*";
              default = "1";
              description = "Nix seed epoch embedded in the image's /nix volume.";
            };
          };
        }
      );
      default = { };
      description = "Offline OCI images available to runner VMs.";
    };

    nixCacheMinFreeMiB = mkOption {
      type = types.ints.positive;
      default = 4096;
      description = "Canonical Nix image free-space floor in MiB.";
    };
    nixCacheMaxFreeMiB = mkOption {
      type = types.ints.positive;
      default = 8192;
      description = "Canonical Nix image free-space target in MiB.";
    };

    runners = mkOption {
      type = types.attrsOf (
        types.submodule (
          {
            config,
            name,
            ...
          }:
          {
            options = {
              enable = mkEnableOption "the ${name} Forgejo runner VM" // {
                default = true;
              };
              vmName = mkOption {
                type = types.strMatching "[a-zA-Z0-9_-]+";
                default = "forgejo-runner-${name}";
                description = "Unique microVM and host systemd instance name.";
              };
              tapName = mkOption {
                type = types.strMatching "[a-zA-Z0-9_.-]{1,15}";
                description = "Unique host TAP interface name, limited by Linux IFNAMSIZ.";
              };
              subnet = mkOption {
                type = types.strMatching "${ipv4AddressPattern}/30";
                description = "Unique private /30 subnet reserved for this runner.";
              };
              hostAddress = mkOption {
                type = types.strMatching ipv4AddressPattern;
                description = "Explicit host address in subnet.";
              };
              guestAddress = mkOption {
                type = types.strMatching ipv4AddressPattern;
                description = "Explicit guest address in subnet.";
              };
              macAddress = mkOption {
                type = types.strMatching "[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}";
                description = "Unique guest interface MAC address.";
              };
              forgejoProxyPort = mkOption {
                type = types.port;
                default = 18080;
                description = "Forgejo proxy port on the private host address.";
              };
              egress = {
                enable = mkEnableOption "public TCP/443 CONNECT egress for ${name}";
                proxyPort = mkOption {
                  type = types.port;
                  default = 18081;
                  description = "TCP/443 CONNECT proxy port on the private host address.";
                };
              };

              resources = {
                memoryMiB = mkOption {
                  type = types.ints.between 1 9216;
                  default = 4096;
                  description = "Guest memory in MiB; 9 GiB maximum leaves room inside a strict 10 GiB QEMU service limit.";
                };
                vcpus = mkOption {
                  type = types.ints.positive;
                  default = 2;
                  description = "Guest virtual CPU count.";
                };
                runnerStateMiB = mkOption {
                  type = types.ints.positive;
                  default = 4096;
                  description = "Persistent runner state filesystem size in MiB.";
                };
                dockerMiB = mkOption {
                  type = types.ints.positive;
                  default = 8192;
                  description = "Disposable Docker data filesystem size in MiB.";
                };
                workMiB = mkOption {
                  type = types.ints.positive;
                  default = 4096;
                  description = "Disposable job workspace filesystem size in MiB.";
                };
                nixCacheMiB = mkOption {
                  type = types.ints.positive;
                  default = 65536;
                  description = "Persistent fixed-size guest Nix volume filesystem size in MiB.";
                };
                qgroupReservePercent = mkOption {
                  type = types.ints.between 1 100;
                  default = 15;
                  description = "Btrfs qgroup reserve as a percentage of each raw filesystem's declared capacity.";
                };
                qgroupReserveMinMiB = mkOption {
                  type = types.ints.positive;
                  default = 512;
                  description = "Minimum Btrfs qgroup accounting reserve for each raw filesystem.";
                };
                qgroupReserveFloorPercent = mkOption {
                  type = types.ints.between 1 100;
                  default = 25;
                  description = "Minimum percentage of each qgroup reserve that must remain before VM admission.";
                };
                qgroupLimitBudgetMiB = mkOption {
                  type = types.ints.positive;
                  default = 98304;
                  description = "Reviewed upper bound for the sum of this runner's raw filesystem qgroup limits; raise only after validating host capacity.";
                };
              };

              runner = {
                name = mkOption {
                  type = types.str;
                  default = config.vmName;
                  description = "Name registered with Forgejo.";
                };
                tokenSecret = mkOption {
                  type = types.str;
                  default = "forgejo_runner_token";
                  description = "Host SOPS secret containing the registration token.";
                };
                tokenSopsFile = mkOption {
                  type = types.str;
                  default = "secrets/server-legion/forgejo-runner.yaml";
                  description = "Repository-relative SOPS file containing the host-decrypted token.";
                };
                labels = mkOption {
                  type = types.listOf types.str;
                  default = [ "${name}:docker://forgejo-runner-node:20-bookworm-slim" ];
                  description = "Runner labels and their preseeded Docker execution images.";
                };
                imageNames = mkOption {
                  type = types.listOf types.str;
                  default = [
                    "node"
                    "nix"
                  ];
                  description = "Keys from actions.images seeded before runner startup.";
                };
                nixSeedEpoch = mkOption {
                  type = types.strMatching "[1-9][0-9]*";
                  default = "2";
                  description = "Expected /nix seed epoch; changing it requires the owner cache reset.";
                };
                capacity = mkOption {
                  type = types.ints.positive;
                  default = 1;
                  description = "Maximum concurrent jobs in this VM.";
                };
              };
            };
          }
        )
      );
      default = { };
      description = "Isolated persistent Forgejo runner VMs.";
    };
  };
}
