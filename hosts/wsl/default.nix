{ pkgs, inputs, ... }:
{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ../users/hieronim

    ../common/optional/programs/neovim.nix
    ../common/optional/services/openssh.nix
    ../common/optional/services/dbus.nix
  ];

  wsl = {
    enable = true;
    wslConf = {
      automount.root = "/mnt";
      interop.appendWindowsPath = false;
      network.generateHosts = false;
    };
    defaultUser = "hieronim";
    useWindowsDriver = true;
    wslConf.automount.options = "metadata,uid=1000,gid=1000";
  };
  services.openssh.ports = [ 443 ];

  programs.xwayland.enable = true;
  programs.dconf.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 1048576; # 128 times the default 8192
    "fs.inotify.max_user_instances" = 512; # up from 128
    "fs.inotify.max_queued_events" = 16384; # default small
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
