{
  config,
  lib,
  pkgs,
  ...
}:
let
  profileNames = {
    radarr = "Legion Movies 1080p";
    sonarr = "Legion TV 1080p";
    sonarr-anime = "Legion Anime 1080p";
  };
  mkProfile = name: {
    inherit name;
    min_format_score = 0;
    min_upgrade_format_score = 1;
    reset_unmatched_scores = {
      enabled = true;
      except_patterns = [ "^\\[Legion\\]" ];
    };
    upgrade = {
      allowed = true;
      until_quality = "1080p";
      until_score = 0;
    };
    qualities =
      map
        (resolution: {
          name = "${resolution}p";
          qualities = map (source: "${source}-${resolution}p") [
            "Bluray"
            "WEBDL"
            "WEBRip"
            "HDTV"
          ];
        })
        [
          "1080"
          "720"
        ];
  };
  instances = map (name: {
    inherit name;
    profile = profileNames.${name};
    seerrName =
      {
        radarr = "Radarr";
        sonarr = "Sonarr";
        sonarr-anime = "Sonarr Anime";
      }
      .${name};
    url = "http://${config.nixflix.${name}.connectionAddress}:${
      toString config.nixflix.${name}.config.hostConfig.port
    }/api/v3";
  }) (builtins.attrNames profileNames);
  settings = pkgs.writeText "media-quality.json" (
    builtins.toJSON {
      inherit instances;
      seerrUrl = "http://${config.nixflix.seerr.connectionAddress}:${toString config.nixflix.seerr.port}/api/v1";
    }
  );
  script = ./configure.py;
  externalUrl =
    name:
    lib.optionalString config.nixflix.reverseProxy.enable (
      "${config.nixflix.reverseProxy.httpScheme}://${config.nixflix.${name}.subdomain}."
      + "${config.nixflix.reverseProxy.domain}${config.nixflix.${name}.config.hostConfig.urlBase}"
    );
  mkSonarr = name: {
    hostname = config.nixflix.${name}.connectionAddress;
    port = config.nixflix.${name}.config.hostConfig.port;
    inherit (config.nixflix.${name}.config) apiKey;
    baseUrl = config.nixflix.${name}.config.hostConfig.urlBase;
    activeProfileName = profileNames.${name};
    activeAnimeProfileName = profileNames.${name};
    activeDirectory = builtins.head config.nixflix.${name}.mediaDirs;
    activeAnimeDirectory = builtins.head config.nixflix.${name}.mediaDirs;
    isDefault = name == "sonarr";
    animeSeriesType = if name == "sonarr-anime" then "anime" else "standard";
    externalUrl = externalUrl name;
  };
in
{
  nixflix.recyclarr.config = {
    radarr.radarr = {
      # Keep old profiles and formats intact; only new requests select these profiles.
      delete_old_custom_formats = lib.mkForce false;
      quality_profiles = lib.mkForce [ (mkProfile profileNames.radarr) ];
    };
    sonarr.sonarr = {
      delete_old_custom_formats = lib.mkForce false;
      quality_profiles = lib.mkForce [ (mkProfile profileNames.sonarr) ];
    };
    sonarr.sonarr_anime = {
      delete_old_custom_formats = lib.mkForce false;
      quality_profiles = lib.mkForce [ (mkProfile profileNames.sonarr-anime) ];
    };
  };

  nixflix.seerr = {
    radarr.Radarr = {
      hostname = config.nixflix.radarr.connectionAddress;
      port = config.nixflix.radarr.config.hostConfig.port;
      inherit (config.nixflix.radarr.config) apiKey;
      baseUrl = config.nixflix.radarr.config.hostConfig.urlBase;
      activeDirectory = builtins.head config.nixflix.radarr.mediaDirs;
      activeProfileName = profileNames.radarr;
      externalUrl = externalUrl "radarr";
      isDefault = true;
    };
    sonarr = {
      Sonarr = mkSonarr "sonarr";
      "Sonarr Anime" = mkSonarr "sonarr-anime";
    };
  };

  systemd.services = {
    # Recyclarr cannot define local custom-format conditions, only guide formats.
    media-quality = {
      description = "Configure local media-selection preferences";
      wantedBy = [ "multi-user.target" ];
      requires = [ "recyclarr.service" ];
      after = [ "recyclarr.service" ];
      partOf = [ "recyclarr.service" ];
      restartTriggers = [ settings ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.python3}/bin/python3 ${script} ${settings}";
        LoadCredential = map (
          name: "${name}:${config.clan.core.vars.generators.${name}.files.api-key.path}"
        ) (builtins.attrNames profileNames);
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        TimeoutStartSec = 180;
      };
    };
    seerr-radarr = {
      after = [ "media-quality.service" ];
      requires = [ "media-quality.service" ];
      serviceConfig.LoadCredential = [
        "seerr:${config.clan.core.vars.generators.seerr.files.api-key.path}"
        "radarr:${config.clan.core.vars.generators.radarr.files.api-key.path}"
      ];
      # Keep credential-bearing JSON out of curl's command arguments.
      script = lib.mkForce "${pkgs.python3}/bin/python3 ${script} ${settings} seerr-radarr";
    };
    seerr-sonarr = {
      after = [ "media-quality.service" ];
      requires = [ "media-quality.service" ];
      serviceConfig.LoadCredential =
        map (name: "${name}:${config.clan.core.vars.generators.${name}.files.api-key.path}")
          [
            "seerr"
            "sonarr"
            "sonarr-anime"
          ];
      script = lib.mkForce "${pkgs.python3}/bin/python3 ${script} ${settings} seerr-sonarr";
    };
  };
}
