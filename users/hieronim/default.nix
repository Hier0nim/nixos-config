{
  inputs,
  pkgs,
  config,
  lib,
  self,
  ...
}:
let
  inherit (config.custom) username;
  inherit (config.networking) hostName;
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  custom.username = lib.mkDefault "hieronim";

  sops.secrets = {
    user_password_hash = {
      sopsFile = config.custom.repoPath + "/secrets/${hostName}/users.yaml";
    };
    root_password_hash = {
      sopsFile = config.custom.repoPath + "/secrets/${hostName}/users.yaml";
    };
  };

  users = {
    mutableUsers = false;
    users = {
      ${username} = {
        home = "/home/${username}";
        isNormalUser = true;
        uid = 1000;
        extraGroups = lib.flatten [
          "wheel"
          "sops"
          (ifTheyExist [
            "audio"
            "video"
            "docker"
            "git"
            "networkmanager"
            "input"
            "dialout" # Allow access to serial device (for Arduino dev)
            "gamemode"
            "i2c"
          ])
        ];
        hashedPasswordFile = config.sops.secrets.user_password_hash.path;
        shell = pkgs.nushell;
      };

      root = {
        shell = pkgs.nushell;
        hashedPasswordFile = config.sops.secrets.root_password_hash.path;
      };
    };
  };
}
# Import the user's personal/home configurations
// lib.optionalAttrs (inputs ? "home-manager") {
  home-manager = {
    extraSpecialArgs = {
      inherit pkgs inputs self;
      inherit (config.networking) hostName;
    };
    users.${username}.imports = [
      (
        {
          config,
          hostName,
          ...
        }:
        import (lib.custom.relativeToRoot "users/hieronim/${hostName}.nix") {
          inherit
            pkgs
            inputs
            config
            lib
            hostName
            ;
        }
      )
    ];
  };
}
