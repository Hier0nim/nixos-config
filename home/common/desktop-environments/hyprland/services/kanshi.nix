{ pkgs, ... }:

let
  internalSpec = {
    criteria = "eDP-1";
    mode = "2560x1600@60.00Hz";
    position = "0,0";
    scale = 1.333333;
    adaptiveSync = true;
  };

  externals = [
    {
      # NEC 24″
      criteria = "NEC Corporation EA244WMi 57081980NB";
      mode = "1920x1200@59.95Hz";
      position = "1925,0";
      scale = 1.0;
      adaptiveSync = null;
    }

    # -- add more monitors here --
    # {
    #   criteria = "U2721DE";
    #   mode     = "2560x1440@60.00Hz";
    #   position = "2560,0";
    #   scale    = 1.0;
    # }
  ];

  sanitize = s: builtins.replaceStrings [ " " ] [ "_" ] s;

  mkDualProfile = ext: {
    name = "dual-with-${sanitize ext.criteria}";
    outputs = [
      (internalSpec // { status = "enable"; })
      ext
    ];
  };

  mkExtOnlyProfile = ext: {
    name = "external-only-${sanitize ext.criteria}";
    outputs = [
      (internalSpec // { status = "disable"; })
      (ext // { position = "0,0"; })
    ];
  };

  generatedProfiles =
    # laptop only
    [
      {
        name = "laptop-only";
        outputs = [ internalSpec ];
      }
    ]

    # dual-with-X  +  external-only-X   for each known external
    ++ (builtins.concatMap (ext: [
      (mkDualProfile ext)
      (mkExtOnlyProfile ext)
    ]) externals)

    # catch-all profiles for any unknown monitor
    ++ [
      {
        name = "dual-display-any";
        outputs = [
          (internalSpec // { status = "enable"; })
          {
            criteria = "*";
            position = "1925,0";
          }
        ];
      }
      {
        name = "external-only-any";
        outputs = [
          (internalSpec // { status = "disable"; })
          {
            criteria = "*";
            position = "0,0";
          }
        ];
      }
    ];

  externalCriteriaList = builtins.concatStringsSep " " (map (e: "\"${e.criteria}\"") externals);

  lidHandler =
    pkgs.writeScriptBin "lid-handler"
      # nu
      ''
        #!${pkgs.nushell}/bin/nu
        let INTERNAL          = "${internalSpec.criteria}"
        let EXTERNAL_CRITERIA = [ ${externalCriteriaList} ]

        # ─── 1. Read lid state ────────────────────────────────────────────────
        let stateLine = (open /proc/acpi/button/lid/*/state | lines | first 1 | str trim)
        let lidClosed = ($stateLine | str contains "closed").0
        print $"[lid-handler] stateLine=($stateLine)  -> lidClosed=($lidClosed)"

        # ─── 2. Detect enabled external outputs ───────────────────────────────
        let extDescs = (
          hyprctl -j monitors
          | from json
          | where name != $INTERNAL and disabled == false
          | get description
        )
        print $"[lid-handler] enabled external descriptions: (if ($extDescs | is-empty) { 'none' } else { ($extDescs | to text) })"

        # ─── 3. Choose profile helper ─────────────────────────────────────────
        def pick-profile [base] {
          for c in $EXTERNAL_CRITERIA {
            let sanitized = $c | str replace --all ' ' '_'
            if ($extDescs | any {|d| $d =~ $c }) {
                return $"($base)-($sanitized)"
            }
          }
          $"($base)-any"
        }

        # ─── 4. Decide & switch ───────────────────────────────────────────────
        let profile = (if $lidClosed { pick-profile "external-only" } else { pick-profile "dual-with" })
        print $"[lid-handler] switching to profile: ($profile)"
        kanshictl switch $profile
      '';

in
{
  services.kanshi = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings = builtins.map (p: { profile = p; }) generatedProfiles;
  };

  systemd.user = {
    services.lid-switch = {
      Unit = {
        Description = "Handle lid open/close";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lidHandler}/bin/lid-handler";
      };
    };
  };

  systemd.user.services.lid-handler = {
    Unit = {
      Description = "Start lid-handler after kanshi is initialized";
      After = [ "kanshi.service" ];
      Wants = [ "kanshi.service" ];
    };

    Service = {
      ExecStart = "${lidHandler}/bin/lid-handler";
      Type = "simple";
      Restart = "on-failure";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  wayland.windowManager.hyprland.settings = {
    exec-once = [ "${lidHandler}/bin/lid-handler" ];
    bindl = [
      ", switch:on:Lid Switch,  exec, systemctl --user start lid-switch.service"
      ", switch:off:Lid Switch, exec, systemctl --user start lid-switch.service"
    ];
  };
}
