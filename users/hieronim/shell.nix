{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs = {
    bash = {
      enable = true;
      shellAliases = {
        c = "clear";
        la = "ls -la";
        ll = "ls -l";
        nv = "nvim";
      };
    };

    zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;
      syntaxHighlighting.enable = true;
      defaultKeymap = "viins";
      history = {
        size = 10000;
        save = 10000;
        share = true;
        ignoreSpace = true;
      };
      shellAliases = {
        c = "clear";
        nv = "nvim";
        ll = "ls -l";
        la = "ls -la";
        nd = "nix develop -c zsh";
        tree = "eza --git --icons --tree";
        cat = "bat";
      };
      initContent = lib.mkOrder 1100 ''
        # Keep completion on Tab and Deja acceptance on the arrow keys.
        zstyle ':completion:*' menu select
        zmodload zsh/complist
        bindkey -M viins '^I' expand-or-complete
        bindkey -M viins '^[[Z' reverse-menu-complete
        bindkey -M viins '^N' menu-complete
        bindkey -M viins '^P' reverse-menu-complete
        bindkey -M viins '^L' clear-screen
        bindkey -M viins '^R' fzf-history-widget
        bindkey -M vicmd 'i' vi-insert
        bindkey -M vicmd 'a' vi-add-next
        bindkey -M menuselect '^I' menu-complete
        bindkey -M menuselect '^[[Z' reverse-menu-complete
        bindkey -M menuselect '^N' menu-complete
        bindkey -M menuselect '^P' reverse-menu-complete

        export DEJA_CYCLE_KEY=""
        export DEJA_ACCEPT_KEY='^[[C'
        export DEJA_WORD_ACCEPT_KEY='^[[1;5C'
        eval "$(${lib.getExe pkgs.deja} init zsh)"
      '';
    };

    fzf = {
      enable = true;
      historyWidget.options = [ "--bind=ctrl-j:down,ctrl-k:up" ];
    };
    carapace.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    starship = {
      enable = true;
      settings.add_newline = true;
    };
    yazi = {
      enable = true;
      shellWrapperName = "y";
      settings.mgr = {
        show_hidden = false;
        sort_by = "alphabetical";
        sort_dir_first = true;
      };
    };
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        rounded_corners = true;
      };
    };
    bat.enable = true;
    fastfetch = {
      enable = true;
      settings.modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "packages"
        "de"
        "wm"
        "shell"
        "terminal"
        "display"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
      ];
    };
    ghostty = {
      enable = true;
      settings = {
        font-family = "JetBrainsMono Nerd Font Mono";
        font-size = 12;
        theme = "Kanagawa Wave";
        resize-overlay = "never";
        window-decoration = "none";
      };
    };
    zellij.enable = true;
  };

  home.sessionVariables.DIRENV_LOG_FORMAT = "";

  xdg.configFile = {
    "zellij/config.kdl".text =
      builtins.replaceStrings
        [ "@PROJECTS_DIR@" "@HOME_DIR@" ]
        [ "${config.home.homeDirectory}/Projects" config.home.homeDirectory ]
        (builtins.readFile ./files/zellij.kdl);
    "zellij/plugins/zellij-sessionizer.wasm".source = pkgs.fetchurl {
      url = "https://github.com/laperlej/zellij-sessionizer/releases/download/v0.5.0/zellij-sessionizer.wasm";
      hash = "sha256-xBhBwCPnToH5mg/Y2V4FBO0gLfLNuSYE31HJ5OoLoFs=";
    };
  };

  # Preserve the existing policy: graphical logout stops all Zellij sessions.
  systemd.user.services.zellij-cleanup = {
    Unit = {
      Description = "Stop Zellij sessions when the graphical session ends";
      PartOf = [ "graphical-session.target" ];
      Before = [ "exit.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "-${lib.getExe pkgs.zellij} kill-all-sessions -y";
      TimeoutStopSec = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
