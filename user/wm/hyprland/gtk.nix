{ pkgs, settings, ... }:
rec {
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha-Standard-Pink-Dark";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "pink" ];
        size = "standard";
        variant = "mocha";
      };
    };
    cursorTheme.name = "default";
    iconTheme = {
      package = pkgs.catppuccin-papirus-folders.override {
        flavor = "mocha";
        accent = "pink";
      };
      name = "Papirus-Dark";
    };
    font = {
      name = settings.font;
      size = settings.fontSize;
    };
  };

  # Symlink the `~/.config/gtk-4.0/` folder declaratively to theme GTK-4 apps as well.
  xdg.configFile =
    let
      g = gtk.theme.package;
    in
    {
      "gtk-4.0/assets".source = "${g}/share/themes/${g}/gtk-4.0/assets";
      "gtk-4.0/gtk.css".source = "${g}/share/themes/${g}/gtk-4.0/gtk.css";
      "gtk-4.0/gtk-dark.css".source = "${g}/share/themes/${g}/gtk-4.0/gtk-dark.css";
    };
}
