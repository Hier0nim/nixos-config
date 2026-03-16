{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.homelab = {
    enable = mkEnableOption "homelab base";

    domain = mkOption {
      type = types.str;
      default = "pieczarkowo.me";
      description = "Base domain for homelab services.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/data";
      description = "Base directory for homelab content.";
    };

    mediaDir = mkOption {
      type = types.path;
      default = "/data/media";
      description = "Base directory for media libraries.";
    };

    downloadsDir = mkOption {
      type = types.path;
      default = "/data/downloads";
      description = "Directory for downloads.";
    };

    photosDir = mkOption {
      type = types.path;
      default = "/data/photos";
      description = "Directory for the photo library.";
    };

    nasDir = mkOption {
      type = types.path;
      default = "/data/nas";
      description = "Directory for NAS/file-sharing content.";
    };

    services = {
      jellyfin.subdomain = mkOption {
        type = types.str;
        default = "grzybflix";
        description = "Subdomain for Jellyfin.";
      };
      immich.subdomain = mkOption {
        type = types.str;
        default = "fotki";
        description = "Subdomain for Immich.";
      };
      copyparty.subdomain = mkOption {
        type = types.str;
        default = "pliki";
        description = "Subdomain for Copyparty.";
      };
      jellyseerr.subdomain = mkOption {
        type = types.str;
        default = "chciejnik";
        description = "Subdomain for Jellyseerr.";
      };
      audiobookshelf.subdomain = mkOption {
        type = types.str;
        default = "czytelnia";
        description = "Subdomain for Audiobookshelf.";
      };
    };

    media.vpn.wgConfSecretName = mkOption {
      type = types.str;
      default = "nixarr_wireguard";
      description = "SOPS secret name for the WireGuard config used by Transmission.";
    };

    media.enable = mkEnableOption "media stack";
    photos.enable = mkEnableOption "photos stack";
    files.enable = mkEnableOption "file stack";
    proxy.enable = mkEnableOption "reverse proxy stack";
  };
}
