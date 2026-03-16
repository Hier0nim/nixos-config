{
  lib,
  pkgs,
  config,
  ...
}:
{
  programs = {
    nushell = {
      enable = true;

      ## 1. Core settings
      settings = {
        show_banner = false;
        edit_mode = "vi";

        ls.clickable_links = true;
        rm.always_trash = true;

        table = {
          mode = "rounded";
          index_mode = "always";
          header_on_separator = false;
        };

        cursor_shape = {
          vi_insert = "line";
          vi_normal = "block";
        };
      };

      ## 2. Aliases
      shellAliases = {
        # Misc
        c = "clear";
        bash = "${pkgs.bashInteractive}/bin/bash";
        la = "ls -la";
        ll = "ls -l";
        n = "${pkgs.nitch}/bin/nitch";
        nv = "nvim";

        # Nix
        nd = "nix develop -c ${pkgs.nushell}/bin/nu";
        nlu = "nix flake lock --update-input";

        # Modern Unix goodies (opt-in, no shadowing of core tools)
        bat = "${pkgs.bat}/bin/bat";
        df = "${pkgs.duf}/bin/duf";
        fd = "${pkgs.fd}/bin/fd";
        rg = "${pkgs.ripgrep}/bin/rg";
        tree = "${pkgs.eza}/bin/eza --git --icons --tree";
      };

      ## 3. Simple env vars
      environmentVariables = {
        PROMPT_INDICATOR_VI_INSERT = "  ";
        PROMPT_INDICATOR_VI_NORMAL = "∙ ";
        inherit (config.home.sessionVariables)
          EDITOR
          BROWSER
          USERNAME
          ;
      };

      ## 4. Everything else (functions, login magic)
      extraConfig =
        let
          nuScripts = "${pkgs.nu_scripts}/share/nu_scripts/custom-completions";
          src = name: "source ${nuScripts}/${name}/${name}-completions.nu";
          sources = lib.concatStringsSep "\n" (
            map src [
              "zellij"
            ]
          );
        in
        #nu
        ''
          # ── Extra completions from nu_scripts ──
          ${sources}

          # ---- yazi + cwd transfer ----
          # Runs yazi and updates the current directory on exit.
          def --env ff [...args] {
            let tmp = (mktemp -t "yazi-cwd.XXXXXX")
            yazi ...$args --cwd-file $tmp

            let cwd = (if ($tmp | path exists) { open $tmp } else { "" })
            if $cwd != "" and $cwd != $env.PWD {
              cd $cwd
            }

            rm -f $tmp
          }
        '';
    };
  };
}
