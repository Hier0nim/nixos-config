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
}
