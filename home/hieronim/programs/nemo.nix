{pkgs, ...}: {
  home.packages = with pkgs; [
    nemo-with-extensions
    nemo-fileroller
  ];
  dconf = {
    settings = {
      "org/nemo/window-state" = {
        start-with-menu-bar = false;
      };
      "org/nemo/desktop" = {
        show-desktop-icons = false;
      };
    };

    settings."org/cinnamon/desktop/applications/terminal" = {
      exec = "wezterm start --cwd .";
      exec-arg = "start -e ";
    };
  };
}
