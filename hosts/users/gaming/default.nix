{
  inputs,
  pkgs,
  config,
  lib,
  self,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users = {
    mutableUsers = false; # Only allow declarative credentials
    users = {
      gaming = {
        home = "/home/gaming";
        isNormalUser = true;
        extraGroups = lib.flatten [
          (ifTheyExist [
            "audio"
            "video"
            "networkmanager"
          ])
        ];
        hashedPassword = "$y$j9T$A393jWCF3yvUwEwDdalP9/$9JAJVGgOujBcX/SMg8zRuuagNfWH9y6aochFeAsEOC1";
        shell = pkgs.nushell;
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
    users.gaming.imports = [
      (
        {
          config,
          hostName,
          ...
        }:
        import (lib.custom.relativeToRoot "home/gaming/${hostName}.nix") {
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
