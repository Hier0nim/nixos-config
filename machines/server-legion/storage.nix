{
  users.groups = {
    media.gid = 169;
    photos = { };
    nas = { };
  };

  systemd.tmpfiles.rules = [
    "d /data/media 2775 root media - -"
    "z /data/media 2775 root media - -"
    "d /data/media/movies 2775 root media - -"
    "d /data/media/tv 2775 root media - -"
    "d /data/media/anime 2775 root media - -"
    "d /data/media/audiobooks 2775 root media - -"
    "d /data/media/books 2775 root media - -"
    "d /data/downloads 2775 root media - -"
    "z /data/downloads 2775 root media - -"
    "d /data/downloads/torrent 2775 root media - -"
    "d /data/photos 2770 root photos - -"
    "z /data/photos 2770 root photos - -"
    "d /data/photos/library 2770 root photos - -"
    "d /data/photos/backups 2770 root photos - -"
    "d /data/photos/profile 2770 root photos - -"
    "d /data/nas 2770 root nas - -"
    "z /data/nas 2770 root nas - -"
    "d /data/nas/shared 2770 root nas - -"
    "d /data/nas/hieronim 2770 root nas - -"
    "d /data/nas/sarka 2770 root nas - -"
  ];
}
