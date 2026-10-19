{
  services.logind.settings.Login = {
    # Use native timed hibernation on both battery and AC power.
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";

    # Closing the lid must not sleep a docked workstation.
    HandleLidSwitchDocked = "ignore";
  };
}
