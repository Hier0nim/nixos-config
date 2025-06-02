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
      hieronim = {
        home = "/home/hieronim";
        isNormalUser = true;
        uid = 1000;
        extraGroups = lib.flatten [
          "wheel"
          (ifTheyExist [
            "audio"
            "video"
            "docker"
            "git"
            "networkmanager"
            "input"
          ])
        ];
        hashedPassword = "$y$j9T$A393jWCF3yvUwEwDdalP9/$9JAJVGgOujBcX/SMg8zRuuagNfWH9y6aochFeAsEOC1";
        shell = pkgs.nushell;
      };

      root = {
        shell = pkgs.nushell;
        hashedPassword = "$y$j9T$Vh7yCdbgKEzY59Z2cI3Vr/$JspXXRYmAAhD8NCxx4cdm0o2VQETx8aXxTlG/8dz/W9";
      };
    };
  };
  programs.git.enable = true;
}
# Import the user's personal/home configurations
// lib.optionalAttrs (inputs ? "home-manager") {
  home-manager = {
    extraSpecialArgs = {
      inherit pkgs inputs self;
      inherit (config.networking) hostName;
    };
    users.hieronim.imports = [
      (
        {
          config,
          hostName,
          ...
        }:
        import (lib.custom.relativeToRoot "home/hieronim/${hostName}.nix") {
          inherit
            pkgs
            inputs
            config
            lib
            hostName
            ;
        }
      )

      inputs.cosmic-manager.homeManagerModules.cosmic-manager
    ];
  };
}
