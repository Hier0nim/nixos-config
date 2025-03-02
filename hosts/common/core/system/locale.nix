{lib, ...}: let
  timezone = lib.mkDefault "Europe/Warsaw";
  locale = lib.mkDefault "en_US.UTF-8";
in {
  time = {
    timeZone = timezone;
    hardwareClockInLocalTime = lib.mkDefault true;
  };
  i18n = {
    defaultLocale = locale;
    extraLocaleSettings.LC_ALL = locale;
  };
}
