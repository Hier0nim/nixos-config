{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  varFiles = config.clan.core.vars.generators.copyparty.files;
  passwords = {
    admin = varFiles.admin-password.path;
    hieronim = varFiles.hieronim-password.path;
    sarcia = varFiles.sarka-password.path;
  };
  idpFiles = config.clan.core.vars.generators.copyparty-idp.files;
  domain = config.services.homelabIngress.domain;
  guard = "-d 127.0.0.1/32 -p tcp --dport 3923 -j copyparty-local";
  volumeFlags = {
    e2d = true;
    d2t = true;
    scan = 60;
    fk = 4;
  };
in
{
  imports = [ self.inputs.copyparty.nixosModules.default ];

  clan.core.vars.generators.copyparty = {
    files = {
      admin-password = {
        owner = "copyparty";
        group = "copyparty";
        mode = "0400";
      };
      hieronim-password = {
        owner = "copyparty";
        group = "copyparty";
        mode = "0400";
      };
      sarka-password = {
        owner = "copyparty";
        group = "copyparty";
        mode = "0400";
      };
    };
    prompts = {
      admin-password = {
        description = "Copyparty administrator password";
        type = "hidden";
      };
      hieronim-password = {
        description = "Copyparty Hieronim account password";
        type = "hidden";
      };
      sarka-password = {
        description = "Copyparty Sarka account password";
        type = "hidden";
      };
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      install -m 0400 "$prompts/admin-password" "$out/admin-password"
      install -m 0400 "$prompts/hieronim-password" "$out/hieronim-password"
      install -m 0400 "$prompts/sarka-password" "$out/sarka-password"
    '';
  };

  clan.core.vars.generators.copyparty-idp = {
    files = lib.genAttrs [ "header-name" "proxy.caddy" ] (_: {
      owner = "root";
      group = "root";
      mode = "0400";
    });
    runtimeInputs = [ pkgs.python3 ];
    script = ''
      umask 077
      python3 - <<'PY'
      import os
      from pathlib import Path
      import secrets

      name = "x-copyparty-proof-" + secrets.token_hex(32)
      output = Path(os.environ["out"])
      (output / "header-name").write_text(name)
      (output / "proxy.caddy").write_text("header_up " + name + " 1\n")
      for path in output.iterdir():
          path.chmod(0o400)
      PY
    '';
  };

  users.users.copyparty.extraGroups = [ "nas" ];

  # Indexes belong to the daemon, independently of uploaded content ownership.
  systemd.tmpfiles.rules = lib.concatMap (volume: [
    "d ${volume.path}/.hist 0700 copyparty copyparty - -"
    "Z ${volume.path}/.hist - copyparty copyparty - -"
    "z ${volume.path}/.hist/up2k.db* 0600 copyparty copyparty - -"
  ]) (lib.attrValues config.services.copyparty.volumes);

  services.caddy.virtualHosts."pliki.${domain}".extraConfig = lib.mkForce (
    import ./proxy.nix {
      upstream = config.services.homelabIngress.services.pliki.upstream;
      proofSnippet = "/run/caddy/copyparty-idp.caddy";
    }
  );

  services.copyparty = {
    enable = true;
    user = "copyparty";
    group = "copyparty";
    openFilesLimit = 8192;

    settings = {
      i = "127.0.0.1";
      p = 3923;
      rproxy = 1;
      xff-src = "127.0.0.1/32";
      idp-h-usr = "X-Copyparty-User";
      idp-h-key = "@@COPYPARTY_IDP_KEY@@";
      # Keep native password clients; never persist SSO sessions independently of the proxy.
      idp-cookie = 0;
      idp-store = 0;
    };

    accounts = {
      admin.passwordFile = passwords.admin;
      hieronim.passwordFile = passwords.hieronim;
      sarcia.passwordFile = passwords.sarcia;
    };

    groups.shared = [
      "hieronim"
      "sarcia"
    ];

    volumes = {
      "/nas/shared" = {
        path = "/data/nas/shared";
        access.rwmd = [
          "admin"
          "hieronim"
          "sarcia"
        ];
        flags = volumeFlags;
      };
      "/nas/hieronim" = {
        path = "/data/nas/hieronim";
        access.rwmd = [
          "admin"
          "hieronim"
        ];
        flags = volumeFlags;
      };
      "/nas/sarcia" = {
        path = "/data/nas/sarcia";
        access.rwmd = [
          "admin"
          "sarcia"
        ];
        flags = volumeFlags;
      };
    };
  };

  systemd.services = {
    caddy = {
      requires = [ "copyparty-local-guard.service" ];
      after = [ "copyparty-local-guard.service" ];
      # Reload commands cannot use the startup credential namespace for imports.
      preStart = lib.mkBefore ''
        ${pkgs.coreutils}/bin/install -m 0400 "$CREDENTIALS_DIRECTORY/copyparty-idp-proxy" /run/caddy/copyparty-idp.caddy
      '';
      serviceConfig.LoadCredential = [ "copyparty-idp-proxy:${idpFiles."proxy.caddy".path}" ];
    };
    copyparty = {
      requires = [ "copyparty-local-guard.service" ];
      after = [ "copyparty-local-guard.service" ];
      preStart = lib.mkAfter ''
        ${pkgs.python3}/bin/python3 - <<'PY'
        import os
        from pathlib import Path
        import re

        name = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "idp-header-name").read_text().strip()
        if not re.fullmatch(r"x-copyparty-proof-[a-f0-9]{64}", name):
            raise SystemExit("Invalid Copyparty proxy credential")
        path = Path("/run/copyparty/copyparty.conf")
        text = path.read_text()
        if text.count("@@COPYPARTY_IDP_KEY@@") != 1:
            raise SystemExit("Missing Copyparty proxy credential placeholder")
        path.write_text(text.replace("@@COPYPARTY_IDP_KEY@@", name))
        PY
      '';
      serviceConfig = {
        SupplementaryGroups = [ "nas" ];
        UMask = lib.mkForce "0022";
        LoadCredential = [ "idp-header-name:${idpFiles.header-name.path}" ];
      };
    };
    copyparty-local-guard = {
      description = "Restrict Copyparty's trusted-header listener to its proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "firewall.service" ];
      before = [
        "caddy.service"
        "copyparty.service"
      ];
      path = [ pkgs.iptables ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        iptables -N copyparty-local 2>/dev/null || true
        iptables -F copyparty-local
        iptables -A copyparty-local -m owner --uid-owner 0 -j RETURN
        iptables -A copyparty-local -m owner --uid-owner caddy -j RETURN
        iptables -A copyparty-local -p tcp -j REJECT --reject-with tcp-reset
        iptables -C OUTPUT ${guard} 2>/dev/null || iptables -I OUTPUT 1 ${guard}
      '';
      preStop = ''
        while iptables -D OUTPUT ${guard} 2>/dev/null; do :; done
        iptables -F copyparty-local 2>/dev/null || true
        iptables -X copyparty-local 2>/dev/null || true
      '';
    };
  };
}
