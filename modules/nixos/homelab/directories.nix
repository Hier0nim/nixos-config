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
    users.groups.media = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
      "d ${cfg.dataDir}/.state 0755 root root - -"

      # Base directories only.
      # Service-specific ownership/permissions are handled in the service modules.
      "d ${cfg.mediaDir} 2775 root media - -"
      "Z ${cfg.mediaDir} 2775 root media - -"
      "d ${cfg.mediaDir}/movies 2775 root media - -"
      "Z ${cfg.mediaDir}/movies 2775 root media - -"
      "d ${cfg.mediaDir}/shows 2775 root media - -"
      "Z ${cfg.mediaDir}/shows 2775 root media - -"
      "d ${cfg.mediaDir}/music 2775 root media - -"
      "Z ${cfg.mediaDir}/music 2775 root media - -"
      "d ${cfg.mediaDir}/ebooks 2775 root media - -"
      "Z ${cfg.mediaDir}/ebooks 2775 root media - -"
      "d ${cfg.mediaDir}/audiobooks 2775 root media - -"
      "Z ${cfg.mediaDir}/audiobooks 2775 root media - -"
      "d ${cfg.downloadsDir} 0750 root root - -"
    ];
  };
}
