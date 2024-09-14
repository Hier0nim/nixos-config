{pkgs, ...}:
let
  inherit (import ../home/options.nix) userName userFullName;
in {
  users = {
    mutableUsers = true;
    users.${userName} = {
      isNormalUser = true;
      description = "${userFullName}";
      extraGroups = ["networkmanager" "wheel"];
      hashedPassword = "$y$j9T$bIyZhxYrycF/ATJIjJjfe0$a6Mr8P598yR/ngzdvTbjr.krh/Tx0Fnj0nUC6gkLEJ8";
      shell = pkgs.nushell;
    };
  };

  # The line below enables crucial system components necessary for Hyprland to run properly.
  programs.hyprland.enable = true;

  # This is required by Hyprlock. The package installed through home-manager will not be able to unlock the session
  # without this configuration. Vaxry added a fallback to 'su' though.
  security.pam.services.hyprlock = {};
}
