{
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            cryptroot = {
              end = "-16G";
              content = {
                type = "luks";
                name = "cryptroot";
                askPassword = true;
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@var" = {
                      mountpoint = "/var";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@containers" = {
                      mountpoint = "/var/lib/containers";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                  };
                };
              };
            };
            swap = {
              size = "100%";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
          };
        };
      };

      hdd0 = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            cryptdata = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptdata";
                askPassword = true;
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "@data" = {
                      mountpoint = "/data";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@photos" = {
                      mountpoint = "/data/photos";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@nas" = {
                      mountpoint = "/data/nas";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@media" = {
                      mountpoint = "/data/media";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@downloads" = {
                      mountpoint = "/data/downloads";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
