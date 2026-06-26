{ config, lib, ... }:
let
  cfg = config.custom.hardware.audio;
in
{
  options.custom.hardware.audio = {
    enable = lib.mkEnableOption "PipeWire audio support";
    support32Bit = lib.mkEnableOption "32-bit ALSA support for Steam, Wine, and Proton";
  };

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = cfg.support32Bit;
      pulse.enable = true;
      audio.enable = true;
      wireplumber.enable = true;
      # jack.enable = true;
    };
  };
}
