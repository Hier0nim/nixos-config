{
  pkgs,
  inputs,
  ...
}:
{
  home.packages = with pkgs; [
    (heroic.override {
      extraPkgs = pkgs: [
        pkgs.gamescope
        pkgs.gamemode
      ];
    })
    minion
    prismlauncher
    (import inputs.creamlinux-installer { inherit pkgs; })
  ];

  xdg.configFile."gamescope/scripts/gamescope-explicit-sync-off.lua" = {
    force = true;
    text =
      # lua
      ''
        function info(text)
            gamescope.log(gamescope.log_priority.info, text)
        end


        info("Disabling explicit sync: " .. tostring(gamescope.convars.drm_debug_disable_explicit_sync.value) .. " -> " .. tostring(true))
        gamescope.convars.drm_debug_disable_explicit_sync.value = true
      '';
  };
}
