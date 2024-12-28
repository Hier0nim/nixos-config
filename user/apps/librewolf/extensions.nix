# Extensions are obtained thanks to the guide here: https://discourse.nixos.org/t/declare-firefox-extensions-and-settings/36265.
# Check `about:support` for extension/add-on ID strings. Then find the
# installation url by donwloading the extension file (instead of installing it
# directly). Always install the latest version of the extensions by using the
# "latest" tag in the download url.
{
  # Canvas Blocker
  "CanvasBlocker@kkapsner.de" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/file/4262820/canvasblocker-latest.xpi";
    installation_mode = "force_installed";
  };
  # Proton pass
  "78272b6fa58f4a1abaac99321d503a20@proton.me" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/file/4355813/proton_pass-latest.xpi";
    installation_mode = "force_installed";
  };
  # Tridactyl
  "tridactyl.vim@cmcaine.co.uk" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/file/4261352/tridactyl_vim-latest.xpi";
    installation_mode = "force_installed";
  };
  # Catppuccin mocha
  "{8446b178-c865-4f5c-8ccc-1d7887811ae3}" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/file/3990315/catppuccin_mocha_lavender_git-latest.xpi";
    installation_mode = "force_installed";
  };
  # GPThemes
  "gpthemes@itsmarta" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/file/4384792/gpthemes-latest.xpi";
    installation_mode = "force_installed";
  };
  # SideBerry
  "{3c078156-979c-498b-8990-85f7987dd929}" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/file/4246774/sidebery-latest.xpi";
    installation_mode = "force_installed";
  };
  # Userchrome Toggle Extended
  "userchrome-toggle-extended@n2ezr.ru" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/file/4341014/userchrome_toggle_extended-latest.xpi";
    installation_mode = "force_installed";
  };
}
