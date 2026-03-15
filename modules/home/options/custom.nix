{ lib, ... }:
let
  inherit (lib) types;
in
{
  options.custom = {
    username = lib.mkOption {
      type = types.str;
      description = "Primary user name for Home Manager.";
    };

    fullName = lib.mkOption {
      type = types.str;
      description = "Full name for user-facing programs (e.g. Git).";
    };

    email = lib.mkOption {
      type = types.str;
      description = "Primary email for user-facing programs (e.g. Git).";
    };

    repoPath = lib.mkOption {
      type = types.path;
      description = "Path to the flake repository.";
    };

    wallpaper = lib.mkOption {
      type = types.path;
      description = "Default wallpaper image.";
    };
  };
}
