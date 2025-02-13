{
  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      "dimaround, class:^(gcr-prompter)$"
      "dimaround, class:^(polkit-gnome-authentication-agent-1)$"
      "dimaround, class:^(xdg-desktop-portal-gtk)$"

      "float, class:^(blueman-manager)$"
      "float, class:^(com.saivert.pwvucontrol)$"
      "float, class:^(io.bassi.Amberol)$"
      "float, class:^(io.github.celluloid_player.Celluloid)$"
      "float, class:^(mpv)$"
      "float, class:^(nm-applet)$"
      "float, class:^(nm-connection-editor)$"
      "float, class:^(org.gnome.Calculator)$"
      "float, class:^(org.gnome.Loupe)$"
      "float, class:^(nemo)$"
      "float, class:^(xdg-desktop-portal-gtk)$"

      "float, title:^(File Upload)(.*)$"
      "float, title:^(Library)(.*)$"
      "float, title:^(Open File)(.*)$"
      "float, title:^(Open Folder)(.*)$"
      "float, title:^(Save As)(.*)$"
      "float, title:^(Select a File)(.*)$"

      "float, title:^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$"
      "pin, title:^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$"

      "idleinhibit fullscreen, class:^(.*)$"
      "idleinhibit fullscreen, title:^(.*)$"
      "idleinhibit fullscreen, fullscreen:1"

      "suppressevent maximize, class:.*"
    ];

    workspace = [
      "w[tv1], gapsout:0, gapsin:0"
      "f[1], gapsout:0, gapsin:0"
    ];
  };
}
