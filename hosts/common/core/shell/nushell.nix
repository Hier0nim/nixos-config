{pkgs, ...}: {
  environment = {
    shells = [pkgs.nushell];
  };

  users.defaultUserShell = pkgs.nushell;
}
