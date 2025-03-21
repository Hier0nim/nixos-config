{
  programs.eza = {
    enable = false;
    enableNushellIntegration = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
    colors = "always";
    icons = "always";
    git = true;
  };
}
