{
  inputs,
  lib,
  ...
}:
# Fetch the userName from our home/options.nix file. It will be used to add the user to Nix's "trusted-users" so that we can
# have additional rights when interacting with the Nix daemon.
let
  inherit (import ../home/options.nix) userName;
in
{
  nix = {
    # Keep build-time dependencies around to be able to rebuild while being offline.
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';

    settings = {
      auto-optimise-store = true;
      trusted-users = [ "${userName}" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Enable auto cleanup.
    gc = {
      automatic = true;
      persistent = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  nixpkgs.config.allowUnfree = true;
}
