{ pkgs, ... }:
{
  environment = {
    sessionVariables = {
      # to make Clipboard Manager work
      COSMIC_DATA_CONTROL_ENABLED = 1;
      # enable Ozone Wayland support in Chromium and Electron
      NIXOS_OZONE_WL = "1";
    };

    cosmic.excludePackages = with pkgs; [
      # cosmic-edit
      cosmic-store
      cosmic-term
    ];
  };

  services = {
    desktopManager.cosmic.enable = true;
    displayManager.cosmic-greeter.enable = true;
  };

  security.pam.services = {
    cosmic-greeter.enableGnomeKeyring = true;
  };
  programs.seahorse.enable = true;

  networking.firewall = rec {
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };
}
