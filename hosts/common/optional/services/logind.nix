{
  services.logind = {
    # On battery: suspend
    lidSwitch = "suspend";

    # On AC (external power) but NOT docked: suspend
    lidSwitchExternalPower = "suspend";

    # When docked: ignore
    lidSwitchDocked = "ignore";
  };
}
