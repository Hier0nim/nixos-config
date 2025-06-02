_: {
  environment = {
    sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;

    # cosmic.excludePackages = with pkgs; [
    #   cosmic-edit
    #   cosmic-player
    #   cosmic-store
    #   cosmic-term
    # ];
  };

  services = {
    desktopManager.cosmic.enable = true;
    displayManager.cosmic-greeter.enable = true;
  };
}
