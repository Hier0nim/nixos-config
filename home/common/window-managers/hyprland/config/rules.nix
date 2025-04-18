{
  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      # ─── TAG ASSIGNMENTS ────────────────────────────────────────────────────────
      "tag +system,      class:^(gcr-prompter|polkit-gnome-authentication-agent-1|xdg-desktop-portal-gtk)$"
      "tag +network,     class:^(blueman-manager|nm-applet|nm-connection-editor)$"
      "tag +media,       class:^(com.saivert.pwvucontrol|io.bassi.Amberol|io.github.celluloid_player.Celluloid|mpv)$"
      "tag +file-manager, class:^(nemo)$"
      "tag +dialogs,     title:^(File Upload|Library|Open File|Open Folder|Save As|Select a File)(.*)$"
      "tag +pip,         title:^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
      "tag +tools,       class:^(org.gnome.Calculator|org.gnome.Loupe)$"
      "tag +settings,    class:^(nwg-displays)$"

      # ─── BEHAVIOR RULES (by tag) ────────────────────────────────────────────────
      # dim the background for system‑level dialogs
      "dimaround,           tag:system*"
      # float all small utilities and pop‑ups
      "float,               tag:network*"
      "float,               tag:media*"
      "float,               tag:file-manager*"
      "float,               tag:dialogs*"
      "float,               tag:pip*"
      "float,               tag:settings*"
      # keep PiP always on top
      "pin,                 tag:pip*"
      # float simple tools like calculators
      "float,               tag:tools*"

      # ─── IDLE‑INHIBIT RULES ─────────────────────────────────────────────────────
      # prevent screen sleeping/locking when any app goes fullscreen
      "idleinhibit fullscreen, class:^(.*)$"
      "idleinhibit fullscreen, title:^(.*)$"
      "idleinhibit fullscreen, fullscreen:1"

      # ─── SUPPRESSION RULES ──────────────────────────────────────────────────────
      # ignore all client-initiated maximize requests
      "suppressevent maximize, class:.*"
    ];

    workspace = [
      # ─── SMART‑GAPS: no gaps when exactly one tiled window is present
      "w[tv1], gapsout:0, gapsin:0"
      # ─── SMART‑GAPS: no gaps when exactly one floating window is present
      "f[1],   gapsout:0, gapsin:0"
    ];
  };
}
