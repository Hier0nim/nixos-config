{
  services = {
    howdy = {
      enable = true;
      settings = {
        core = {
          no_confirmation = true;
          abort_if_ssh = true;
        };
        video.dark_threshold = 90;
      };
    };

    # in case your IR blaster does not blink, run `sudo linux-enable-ir-emitter configure`
    linux-enable-ir-emitter = {
      enable = true;
    };
  };

  security.pam.howdy.enable = true;
}
