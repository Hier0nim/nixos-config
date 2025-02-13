{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    audio.enable = true;
    pulse.enable = true;
    # jack.enable = true;
  };

  services.pulseaudio.enable = false;
}
