{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    package = pkgs.yazi;
    enableZshIntegration = true;
    shellWrapperName = "y";
    settings = {
      mgr = {
        show_hidden = false;
        sort_by = "alphabetical";
        sort_dir_first = true;
      };
    };
  };

  home.packages = with pkgs; [
    fd
    ffmpegthumbnailer
    jq
    poppler
    ripgrep
    _7zz
    # (yazi.override {
    #   _7zz = _7zz-rar; # Support for RAR extraction
    # })
  ];
}
