{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ../common/programs
    ../common/packages/archive.nix
    ../common/packages/media.nix
    ../common/shell
    ../common/config/cursor.nix
    ../common/config/xdg.nix
    inputs.umbriel.homeModules.default
    ../desktop/noctalia
  ];

  programs.umbriel = {
    enable = true;
    # Both packages already come from the NixOS modules. Keep config.toml user-owned.
    package = null;
    settings = null;
  };

  dconf.enable = true;

  home.sessionVariables.GSK_RENDERER = "gl";
  systemd.user.sessionVariables.GSK_RENDERER = "gl";

  # Noctalia owns GTK theme and colors; only icon and cursor defaults stay in dconf.
  dconf.settings."org/gnome/desktop/interface" = {
    icon-theme = "Papirus-Dark";
    cursor-theme = "Bibata-Modern-Classic";
    cursor-size = 24;
  };

  home.packages = with pkgs; [
    wl-clipboard
    adw-gtk3
    papirus-icon-theme
  ];
}
