{pkgs, ...}: {
  # see https://nix.dev/permalink/stub-ld.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
  ];
}
