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

    worktreePath = lib.mkOption {
      type = types.str;
      description = "Mutable checkout path for tools that should operate on the live flake worktree.";
    };

    wallpaper = lib.mkOption {
      type = types.path;
      description = "Default wallpaper image.";
    };

    hostName = lib.mkOption {
      type = types.str;
      description = "Host name for host-specific paths (e.g. secrets).";
    };

    home.profiles = {
      desktop.enable = lib.mkEnableOption "desktop home profile";
      dev.enable = lib.mkEnableOption "developer tools profile";
      gaming.enable = lib.mkEnableOption "gaming apps profile";
      remoteAdmin.enable = lib.mkEnableOption "remote admin SSH config";
    };
  };
}
