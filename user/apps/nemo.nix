{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    nemo-with-extensions
    nemo-fileroller
  ];
  dconf = {
    settings."org/nemo/window-state" = {
      start-with-menu-bar = false;
    };
    settings."org/nemo/desktop" = {
      show-desktop-icons = false;
    };

    settings."org/cinnamon/desktop/applications/terminal" = {
      exec = "wezterm start --cwd .";
      exec-arg = "start -e ";
    };
  };

  home.file.".local/share/applications/neovim.desktop" = {
    text = ''
      [Desktop Entry]
      Name=Neovim (WezTerm)
      Comment=Edit text files with Neovim in WezTerm
      Exec=wezterm start -- nvim %f
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Utility;TextEditor;
      MimeType=text/plain;
    '';
  };
}
