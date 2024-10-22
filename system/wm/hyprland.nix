{
  pkgs,
  settings,
  ...
}:
let
  tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
  session = "${pkgs.hyprland}/bin/Hyprland";
in
{
  imports = [
    ./common/fonts.nix
  ];

  environment.systemPackages = with pkgs; [
    wl-clipboard
    brightnessctl
  ];

  programs.hyprland = {
    enable = true;
  };
  services = {
    blueman.enable = true;

    greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "${session}";
          user = "${settings.username}";
        };
        default_session = {
          command = "${tuigreet} --greeting 'Welcome to NixOS!' --asterisks --remember --remember-user-session --time --cmd ${session}";
          user = "greeter";
        };
      };
    };

  };
}
