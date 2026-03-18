{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab;
in
{
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
      "d ${cfg.dataDir}/.state 0750 root root - -"
      "d ${cfg.dataDir}/.state/nixarr 0750 root root - -"

      # Base directories only.
      # Service-specific ownership/permissions are handled in the service modules.
      "d ${cfg.nasDir} 0750 root root - -"
      "d ${cfg.photosDir} 0750 root root - -"
      "d ${cfg.mediaDir} 0755 root root - -"
      "d ${cfg.mediaDir}/movies 0755 root root - -"
      "d ${cfg.mediaDir}/shows 0755 root root - -"
      "d ${cfg.mediaDir}/music 0755 root root - -"
      "d ${cfg.mediaDir}/ebooks 0755 root root - -"
      "d ${cfg.mediaDir}/audiobooks 0755 root root - -"
      "d ${cfg.downloadsDir} 0750 root root - -"
    ];
  };
}
