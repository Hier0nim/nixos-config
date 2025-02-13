{
  pkgs,
  self,
  inputs,
  ...
}:
{
  home.packages = with pkgs; [
    self.packages.${pkgs.system}.lightctl
    self.packages.${pkgs.system}.networkctl
    self.packages.${pkgs.system}.volumectl

    inputs.nixvim.packages.x86_64-linux.default

    amberol
    gcc
    gnumake
    grim
    grimblast
    jq
    p7zip
    ripgrep
    unrar
    unzip
    zip
    wget
    wl-clipboard
    evince
    zathura
    loupe
    spotify
  ];
}
