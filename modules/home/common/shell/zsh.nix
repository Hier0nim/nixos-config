{
  config,
  lib,
  options,
  pkgs,
  inputs,
  ...
}:
let
  # Stable's Deja 0.2.6 hard-binds Tab and lacks DEJA_*_KEY overrides.
  # Use the pinned unstable 0.4.2 on the stable host to keep completion on Tab.
  deja =
    if inputs ? nixpkgs-unstable then
      inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.deja
    else
      pkgs.deja;
in
{
  home.packages = with pkgs; [
    deja
    duf
    eza
    trash-cli
  ];

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  }
  // (
    if options.programs.fzf ? historyWidget then
      { historyWidget.options = [ "--bind=ctrl-j:down,ctrl-k:up" ]; }
    else
      { historyWidgetOptions = [ "--bind=ctrl-j:down,ctrl-k:up" ]; }
  );

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = config.home.homeDirectory;
    autosuggestion.enable = false;
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
      # Complete on Tab in a selectable menu, never accept a ghost on Tab.
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
      # Once completion opens its own keymap, keep navigation consistent.
      bindkey -M menuselect '^I' menu-complete
      bindkey -M menuselect '^[[Z' reverse-menu-complete
      bindkey -M menuselect '^N' menu-complete
      bindkey -M menuselect '^P' reverse-menu-complete

      # Deja's generated init binds keys and wraps ZLE widgets on precmd.
      # Explicit empty cycle key prevents it from claiming completion's Tab.
      export DEJA_CYCLE_KEY=""
      export DEJA_ACCEPT_KEY='^[[C'
      export DEJA_WORD_ACCEPT_KEY='^[[1;5C'
      eval "$(${lib.getExe deja} init zsh)"
    '';
  };
}
