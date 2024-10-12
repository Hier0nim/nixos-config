{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "float,udiskie"
      "float,title:^(Transmission)$"
      "float,title:^(Volume Control)$"
      "size 700 450,title:^(Volume Control)$"
      "size 700 450,title:^(Save As)$"
      "float,title:^(Library)$"
      "size 700 450,title:^(Page Info)$"
      "float,title:^(Page Info)$"
    ];
    windowrulev2 = [
      "float,class:^(pavucontrol)$"
      "float,class:^(file_progress)$"
      "float,class:^(confirm)$"
      "float,class:^(.protonvpn-app-wrapped)$"
      "float,class:^(.blueman-manager-wrapped)$"
      "float,class:^(dialog)$"
      "float,class:^(download)$"
      "float,class:^(notification)$"
      "float,class:^(nm-connection-editor)$"
      "float,title:^(File Operation Progress)$"
      "float,title:^(Open File)$"
      "float,title:^(Save As)$"
      "workspace 9,title:^(vesktop)$"
      "workspace 10,title:^(Spotify)$"
    ];
  };
}
