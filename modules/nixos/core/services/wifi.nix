{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.wifi;
  enabledNetworks = lib.filterAttrs (_: value: value.enable) cfg.networks;
  networkNames = builtins.attrNames enabledNetworks;

  mkSecret = key: {
    inherit key;
    sopsFile = config.custom.repoPath + "/secrets/common/wifi.yaml";
  };

  ssidSecrets = lib.genAttrs (map (name: "${name}_ssid") networkNames) mkSecret;

  pskSecrets = lib.genAttrs (map (name: "${name}_psk") networkNames) mkSecret;

  envLines = map (name: "${name}=${config.sops.placeholder.${name}}") (
    builtins.concatLists [
      (map (name: "${name}_ssid") networkNames)
      (map (name: "${name}_psk") networkNames)
    ]
  );

  profiles = lib.mapAttrs (name: value: {
    connection = {
      id = name;
      type = "wifi";
      inherit (value) autoconnect;
    }
    // lib.optionalAttrs (value.priority != null) {
      autoconnect-priority = value.priority;
    };

    wifi = {
      ssid = "$" + "${name}_ssid";
    };

    wifi-security = {
      key-mgmt = "wpa-psk";
      psk = "$" + "${name}_psk";
    };

    ipv4.method = "auto";
    ipv6.method = "auto";
  }) enabledNetworks;
in
{
  options.custom.wifi = {
    networks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (_: {
          options = {
            enable = lib.mkEnableOption "managed wifi profile";
            autoconnect = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Automatically connect to this network.";
            };
            priority = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Autoconnect priority for this network (higher wins).";
            };
          };
        })
      );
      default = { };
      description = "NetworkManager Wi-Fi profiles managed via SOPS secrets.";
    };
  };

  config = lib.mkIf (networkNames != [ ]) {
    sops.secrets = ssidSecrets // pskSecrets;

    sops.templates."networkmanager-wifi.env" = {
      content = lib.concatStringsSep "\n" envLines;
      path = "/run/NetworkManager/wifi.env";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d /run/NetworkManager 0755 root root - -"
    ];

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [
        "/run/NetworkManager/wifi.env"
      ];
      inherit profiles;
    };
  };
}
