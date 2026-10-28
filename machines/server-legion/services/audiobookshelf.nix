_: {
  users.groups.audiobookshelf = { };
  users.users.audiobookshelf = {
    isSystemUser = true;
    group = "audiobookshelf";
    extraGroups = [ "media" ];
  };

  services.audiobookshelf = {
    enable = true;
    user = "audiobookshelf";
    group = "audiobookshelf";
    host = "127.0.0.1";
    port = 8000;
    openFirewall = false;
  };

  systemd.services.audiobookshelf = {
    unitConfig.RequiresMountsFor = [ "/data/media/audiobooks" ];
    serviceConfig = {
      SupplementaryGroups = [ "media" ];
      UMask = "0002";
    };
  };
}
