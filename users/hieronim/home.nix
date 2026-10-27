{ pkgs, ... }:
{
  imports = [ ./shell.nix ];

  home = {
    stateVersion = "25.05";

    preferXdgDirectories = true;
    sessionVariables = {
      EDITOR = "nvim";
    };
    packages = with pkgs; [
      deja
      duf
      eza
      trash-cli
      fd
      jq
      ripgrep
      _7zz
      gcc
      gnumake
      nixd
      wget
      devenv
      p7zip
      unzip
      zip
      unrar
    ];
  };

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    settings = {
      user = {
        name = "Hier0nim";
        email = "hieronimdaniel@proton.me";
      };
      core.editor = "nvim";
      init.defaultBranch = "main";
      branch.autosetupmerge = "true";
      pull.ff = "only";
      color.ui = "auto";
      push = {
        default = "current";
        followTags = true;
        autoSetupRemote = true;
      };
      merge = {
        conflictstyle = "diff3";
        stat = "true";
      };
      rebase = {
        autoSquash = true;
        autoStash = true;
      };
      rerere = {
        enabled = true;
        autoupdate = true;
      };
      alias = {
        chore = "!f() { git commit -m \"chore($1): $2\"; }; f";
        docs = "!f() { git commit -m \"docs($1): $2\"; }; f";
        feat = "!f() { git commit -m \"feat($1): $2\"; }; f";
        fix = "!f() { git commit -m \"fix($1): $2\"; }; f";
        refactor = "!f() { git commit -m \"refactor($1): $2\"; }; f";
        style = "!f() { git commit -m \"style($1): $2\"; }; f";
        test = "!f() { git commit -m \"test($1): $2\"; }; f";
      };
    };
    ignores = [
      "*~"
      "*.swp"
      "result"
      "result-*"
      ".direnv"
      "node_modules"
    ];
  };

  programs.lazygit.enable = true;
}
