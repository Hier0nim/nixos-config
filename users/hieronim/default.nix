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
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  custom.username = lib.mkDefault "hieronim";

  users = {
    mutableUsers = false;
    users = {
      ${username} = {
        home = "/home/${username}";
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
            "dialout" # Allow access to serial device (for Arduino dev)
            "gamemode"
            "i2c"
          ])
        ];
        # TODO(sops-nix): store hashed password in an encrypted secret.
        hashedPassword = "$y$j9T$A393jWCF3yvUwEwDdalP9/$9JAJVGgOujBcX/SMg8zRuuagNfWH9y6aochFeAsEOC1";
        shell = pkgs.nushell;
      };

      root = {
        shell = pkgs.nushell;
        # TODO(sops-nix): store hashed password in an encrypted secret.
        hashedPassword = "$y$j9T$Vh7yCdbgKEzY59Z2cI3Vr/$JspXXRYmAAhD8NCxx4cdm0o2VQETx8aXxTlG/8dz/W9";
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
