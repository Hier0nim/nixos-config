{
  pkgs,
  lib,
  config,
  ...
}:
{
  programs = {
    direnv = {
      enable = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
    };

    nushell = {
      enable = true;
      shellAliases =
        let
          g = lib.getExe pkgs.git;
          c = "cargo";
        in
        {
          # Cargo
          cb = "${c} build";
          cc = "${c} check";
          cn = "${c} new";
          cr = "${c} run";
          cs = "${c} search";
          ct = "${c} test";

          # Git
          ga = "${g} add";
          gc = "${g} commit";
          gd = "${g} diff";
          gl = "${g} log";
          gs = "${g} status";
          gp = "${g} push origin main";

          # ETC.
          c = "clear";
          f = "${pkgs.yazi-unwrapped}/bin/yazi";
          la = "ls -la";
          ll = "ls -l";
          n = "${pkgs.nitch}/bin/nitch";
          nv = "nvim";

          # Nix
          # ns = "sudo sh -c 'nixos-rebuild switch --flake ${settings.dotfilesDir}/.# |& ${pkgs.nix-output-monitor}/bin/nom'";
          # hs = "home-manager switch --flake ${settings.dotfilesDir}";
          nd = "nix develop -c $env.SHELL";
          nlu = "nix flake lock --update-input";

          # Modern unix
          cat = "${pkgs.bat}/bin/bat";
          df = "${pkgs.duf}/bin/duf";
          find = "${pkgs.fd}/bin/fd";
          grep = "${pkgs.ripgrep}/bin/rg";
          tree = "${pkgs.eza}/bin/eza --git --icons --tree";
        };

      environmentVariables = {
        PROMPT_INDICATOR_VI_INSERT = "  ";
        PROMPT_INDICATOR_VI_NORMAL = "∙ ";
        PROMPT_COMMAND = "";
        PROMPT_COMMAND_RIGHT = "";
        DIRENV_LOG_FORMAT = ""; # make direnv quiet
        EDITOR = "${config.home.sessionVariables.EDITOR}";
        BROWSER = "${config.home.sessionVariables.BROWSER}";
        USERNAME = "${config.home.sessionVariables.USERNAME}";
        SHELL = "${pkgs.nushell}/bin/nu";
      };

      # See the Nushell docs for more options.
      extraConfig =
        let
          conf = builtins.toJSON {
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

            menus = [
              {
                name = "completion_menu";
                only_buffer_difference = false;
                marker = "? ";
                type = {
                  layout = "columnar"; # list, description
                  columns = 4;
                  col_padding = 2;
                };
                style = {
                  text = "magenta";
                  selected_text = "blue_reverse";
                  description_text = "yellow";
                };
              }
            ];
          };
          completion = name: ''
            source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/${name}/${name}-completions.nu
          '';
          completions =
            names:
            builtins.foldl' (prev: str: ''
              ${prev}
              ${str}'') "" (map completion names);
        in
        #nu
        ''
          $env.config = ${conf};
          ${completions [
            "git"
            "nix"
            "man"
            "cargo"
            "zellij"
          ]}

          export def ii [ path ] {
            let _ = /mnt/c/Windows/explorer.exe (wslpath -w $"($path | path expand)")
          }

          def --env ff [...args] {
          	let tmp = (mktemp -t "yazi-cwd.XXXXX")
          	yazi ...$args --cwd-file $tmp
          	let cwd = (open $tmp)
          	if $cwd != "" and $cwd != $env.PWD {
              cd $cwd
          	}
          	rm -fp $tmp
          }

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

          # source ~/.local/cache/zoxide/init.nu
        '';
    };
  };
}
