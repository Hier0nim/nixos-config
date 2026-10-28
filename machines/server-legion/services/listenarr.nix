{ config, pkgs, ... }:
let
  image = "ghcr.io/listenarrs/listenarr:canary-1.3.4@sha256:99b4ae68cf7478dd364c19c3ae379d115ec3b127dfdae5666b0a480de75d8f34";
  libraryDir = "/data/media/audiobooks";
  downloadDir = "/data/downloads/torrent/audiobooks";
  stateDir = "/var/lib/listenarr";
  port = 4545;
  configureScript = pkgs.writeShellApplication {
    name = "configure-listenarr";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec ${pkgs.python3}/bin/python ${./configure-listenarr.py}
    '';
  };
in
{
  users.users.listenarr = {
    isSystemUser = true;
    uid = 1002;
    group = "media";
  };

  virtualisation.oci-containers.containers.listenarr = {
    autoStart = true;
    inherit image;
    environment = {
      ASPNETCORE_URLS = "http://127.0.0.1:${toString port}";
      PUID = "1002";
      PGID = "169";
      UMASK = "002";
    };
    extraOptions = [ "--network=host" ];
    volumes = [
      "${stateDir}:/app/config"
      "${downloadDir}:${downloadDir}"
      "${libraryDir}:${libraryDir}"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 listenarr media - -"
  ];

  systemd.services.listenarr-configure = {
    description = "Apply declarative Listenarr settings";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "docker-listenarr.service"
      "qbittorrent.service"
      "prowlarr.service"
    ];
    requires = [ "docker-listenarr.service" ];
    unitConfig.RequiresMountsFor = [
      downloadDir
      libraryDir
    ];
    restartTriggers = [ configureScript ];
    path = [ pkgs.python3 ];
    environment = {
      LISTENARR_API = "http://127.0.0.1:${toString port}/api/v1";
      LISTENARR_LIBRARY_DIR = libraryDir;
      LISTENARR_DOWNLOAD_DIR = downloadDir;
    };
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      LoadCredential = [
        "qbittorrent-password:${config.clan.core.vars.generators.qbittorrent.files.password.path}"
        "prowlarr-api-key:${config.clan.core.vars.generators.prowlarr.files.api-key.path}"
      ];
      TimeoutStartSec = "infinity";
      Restart = "on-failure";
      RestartSec = "60s";
    };
    script = "${configureScript}/bin/configure-listenarr";
  };
}
