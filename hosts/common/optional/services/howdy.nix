{ inputs, pkgs, ... }:

{
  disabledModules = [ "security/pam.nix" ];
  imports = [
    "${inputs.nixpkgs-howdy}/nixos/modules/security/pam.nix"
    "${inputs.nixpkgs-howdy}/nixos/modules/services/security/howdy"
    "${inputs.nixpkgs-howdy}/nixos/modules/services/misc/linux-enable-ir-emitter.nix"
  ];

  services = {
    howdy = {
      enable = true;
      package = inputs.nixpkgs-howdy.legacyPackages.${pkgs.system}.howdy;
      settings = {
        video.device_path = "/dev/video2";
        core.no_confirmation = true;
      };
    };

    # in case your IR blaster does not blink, run `sudo linux-enable-ir-emitter configure`
    linux-enable-ir-emitter = {
      enable = true;
      package = inputs.nixpkgs-howdy.legacyPackages.${pkgs.system}.linux-enable-ir-emitter;
    };
  };
}
