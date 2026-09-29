{ config, pkgs, ... }:
{
  programs = {
    umbriel.enable = true;
    noctalia.enable = true;
    noctalia.recommendedServices.enable = true;
    dconf.enable = true;
  };

  services.displayManager.noctalia-greeter = {
    enable = true;
    settings = {
      session.default = "Umbriel";
      user.default = config.custom.username;
      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
      };
    };
    cursorTheme.package = pkgs.bibata-cursors;
  };
}
