_: {
  programs.noctalia = {
    enable = true;
    package = null;
    # Noctalia is the only authentication agent in this session.
    settings.shell.polkit_agent = true;
  };
}
