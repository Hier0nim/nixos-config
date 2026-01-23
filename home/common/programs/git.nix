{
  pkgs,
  config,
  ...
}:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    settings = {
      user = {
        name = "Hier0nim";
        email = "hieronimdaniel@proton.me";
      };

      core.editor = "${config.home.sessionVariables.EDITOR}";
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
        # Semantic commit message aliases
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
      "*result*"
      ".direnv"
      "node_modules"
    ];
  };
}
