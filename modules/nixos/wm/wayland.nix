{ ... }:

{
  imports = [ ./pipewire.nix
              ./dbus.nix
              ./gnome-keyring.nix
              ./fonts.nix
            ];

  # Configure xwayland
  services.xserver = {
    enable = true;
    xkb = {
      layout = "pl";
      variant = "";
    };
  };
}
