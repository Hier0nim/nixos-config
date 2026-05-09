{ config, lib, ... }:
let
  inherit (lib) types;
in
{
  options.custom = {
    hostRole = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "High-level role for this host (e.g. laptop, server).";
    };

    username = lib.mkOption {
      type = types.str;
      default = "hieronim";
      description = "Primary local user name.";
    };

    email = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Primary user email (if needed by system modules).";
    };

    repoPath = lib.mkOption {
      type = types.path;
      default = lib.custom.relativeToRoot ".";
      description = "Path to the flake repository.";
    };

    worktreePath = lib.mkOption {
      type = types.str;
      default = "/home/${config.custom.username}/Projects/nixos-config";
      description = "Mutable checkout path for tools that should operate on the live flake worktree.";
    };
  };
}
