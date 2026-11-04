{
  config,
  lib,
  pkgs,
  ...
}:
let
  photos = "/data/photos";
  oidcFiles = config.clan.core.vars.generators.immich-oidc.files;
in
{
  clan.core.vars.generators.immich-oidc = {
    files = {
      client-secret = {
        owner = "immich";
        group = "immich";
        mode = "0400";
      };
      client-hash = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.argon2-cffi ])) ];
    script = "python3 ${../identity/generate-oidc-client.py}";
  };

  services.authelia.instances.homelab.settings.identity_providers.oidc = {
    authorization_policies.immich = {
      default_policy = "deny";
      rules = [
        {
          policy = "one_factor";
          subject = "group:household";
        }
      ];
    };
    clients = [
      {
        client_id = "immich";
        client_name = "Immich";
        client_secret = ''{{ mustEnv "CREDENTIALS_DIRECTORY" | printf "%s/immich-client-hash" | secret }}'';
        public = false;
        authorization_policy = "immich";
        consent_mode = "implicit";
        require_pkce = true;
        pkce_challenge_method = "S256";
        redirect_uris = [
          "https://fotki.${config.services.homelabIngress.domain}/auth/login"
          "https://fotki.${config.services.homelabIngress.domain}/user-settings"
          "app.immich:///oauth-callback"
        ];
        scopes = [
          "openid"
          "email"
          "profile"
        ];
        response_types = [ "code" ];
        grant_types = [ "authorization_code" ];
        token_endpoint_auth_method = "client_secret_post";
        id_token_signed_response_alg = "RS256";
      }
    ];
  };
  systemd.services.authelia-homelab.serviceConfig.LoadCredential = [
    "immich-client-hash:${oidcFiles.client-hash.path}"
  ];

  users.users.immich.extraGroups = [
    "photos"
    "render"
    "video"
  ];

  services.immich = {
    enable = true;
    package = pkgs.immich;
    host = "127.0.0.1";
    port = 2283;
    openFirewall = false;
    mediaLocation = photos;
    accelerationDevices = [
      "/dev/nvidia0"
      "/dev/nvidiactl"
      "/dev/nvidia-modeset"
      "/dev/nvidia-uvm"
      "/dev/nvidia-uvm-tools"
    ];
    settings = {
      newVersionCheck.enabled = false;
      oauth = {
        enabled = true;
        issuerUrl = "https://auth.${config.services.homelabIngress.domain}";
        clientId = "immich";
        clientSecret._secret = oidcFiles.client-secret.path;
        scope = "openid email profile";
        signingAlgorithm = "RS256";
        tokenEndpointAuthMethod = "client_secret_post";
        autoRegister = false;
        autoLaunch = false;
        buttonText = "Authelia";
        # Keep existing roles; admission claims must not change native administrators.
        roleClaim = "";
      };
      ffmpeg = {
        accel = "nvenc";
        accelDecode = true;
      };
      server.externalDomain = "https://fotki.pieczarkowo.me";
      storageTemplate = {
        enabled = true;
        hashVerificationEnabled = true;
        template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
      };
    };
  };

  systemd = {
    tmpfiles.rules = map (name: "d ${photos}/${name} 2770 root photos - -") [
      "upload"
      "thumbs"
      "encoded-video"
      "profile"
    ];
    services.immich-server = {
      unitConfig.RequiresMountsFor = [ photos ];
      # Preserve access through the shared photos group.
      serviceConfig.PrivateUsers = lib.mkForce false;
    };
    tmpfiles.settings.immich = lib.mkForce { };
  };
}
