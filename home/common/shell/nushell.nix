{
  pkgs,
  lib,
  config,
  ...
}:

let
  git = lib.getExe pkgs.git;
in
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
        # Cargo
        cb = "cargo build";
        cc = "cargo check";
        cn = "cargo new";
        cr = "cargo run";
        cs = "cargo search";
        ct = "cargo test";

        # Git
        ga = "${git} add";
        gc = "${git} commit";
        gd = "${git} diff";
        gl = "${git} log";
        gs = "${git} status";
        gp = "${git} push origin main";

        # Misc
        c = "clear";
        f = "${pkgs.yazi-unwrapped}/bin/yazi";
        la = "ls -la";
        ll = "ls -l";
        n = "${pkgs.nitch}/bin/nitch";
        nv = "nvim";

        # Nix
        nd = "nix develop -c $env.SHELL";
        nlu = "nix flake lock --update-input";

        # Modern-Unix goodies
        cat = "${pkgs.bat}/bin/bat";
        df = "${pkgs.duf}/bin/duf";
        find = "${pkgs.fd}/bin/fd";
        grep = "${pkgs.ripgrep}/bin/rg";
        tree = "${pkgs.eza}/bin/eza --git --icons --tree";
      };

      ## 3. Simple env vars
      environmentVariables = {
        PROMPT_INDICATOR_VI_INSERT = "  ";
        PROMPT_INDICATOR_VI_NORMAL = "∙ ";
        PROMPT_COMMAND = "";
        PROMPT_COMMAND_RIGHT = "";
        DIRENV_LOG_FORMAT = "";
        inherit (config.home.sessionVariables)
          EDITOR
          BROWSER
          USERNAME
          ;
        SHELL = "${pkgs.nushell}/bin/nu";
        ZELLIJ_AUTO_START = lib.mkDefault false;
      };

      ## 4. Everything else (functions, sources, login magic)
      extraConfig =
        let
          nuScripts = "${pkgs.nu_scripts}/share/nu_scripts/custom-completions";
          src = name: "source ${nuScripts}/${name}/${name}-completions.nu";
          sources = lib.concatStringsSep "\n" (
            map src [
              "git"
              "nix"
              "man"
              "cargo"
              "zellij"
              "zoxide"
            ]
          );
        in
        #nu
        ''
          # ── Extra completions from nu_scripts ──
          ${sources}

          # ---- yazi + cwd transfer ----
          def --env ff [...args] {
          	let tmp = (mktemp -t "yazi-cwd.XXXXX")
          	yazi ...$args --cwd-file $tmp
          	let cwd = (open $tmp)
          	if $cwd != "" and $cwd != $env.PWD {
              cd $cwd
          	}
          	rm -fp $tmp
          }

          # ---- ssh-agent bootstrap ----
          do --env {
            let ssh_agent_file = (
              $nu.temp-path | path join $"ssh-agent-($env.USER? | default $env.USERNAME?).nuon"
            )

            if ($ssh_agent_file | path exists) {
              let ssh_agent_env = open ($ssh_agent_file)
              if ($"/proc/($ssh_agent_env.SSH_AGENT_PID)" | path exists) {
                load-env $ssh_agent_env
                return
              } else {
                rm $ssh_agent_file
              }
            }

            let ssh_agent_env = ^ssh-agent -c
              | lines
              | first 2
              | parse "setenv {name} {value};"
              | transpose --header-row
              | into record
            load-env $ssh_agent_env
            $ssh_agent_env | save --force $ssh_agent_file
          }

          # ---- zellij autostart ----
          if ($env.ZELLIJ_AUTO_START == true) {
            do --env {
              if 'ZELLIJ' not-in ($env | columns) {
                if 'ZELLIJ_AUTO_ATTACH' in ($env | columns) and $env.ZELLIJ_AUTO_ATTACH == 'true' {
                  ^zellij attach --create
                } else {
                  zellij -l welcome
                }

                if 'ZELLIJ_AUTO_EXIT' in ($env | columns) and $env.ZELLIJ_AUTO_EXIT == 'true' {
                  exit
                }
              }
            }
          }
        '';
    };
  };
}
