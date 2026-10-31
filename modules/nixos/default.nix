{lib, ...}: let
  inherit (lib) mkDefault;
in {
  i18n = {
    defaultLocale = "de_AT.UTF-8";
    supportedLocales = [
      "de_AT.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_TIME = "de_AT.UTF-8";
    };
  };

  hardware.enableRedistributableFirmware = mkDefault true;

  programs.nix-ld.enable = true;

  # Substituters, experimental features, store optimisation and garbage
  # collection are shared across platforms and live in modules/common/nix.nix.
  # nix-darwin schedules collection with `interval` instead of `dates`.
  nix = {
    settings.trusted-users = [
      "root"
      "@wheel"
    ];

    gc.dates = mkDefault "weekly";
  };

  time.timeZone = "Europe/Vienna";
}
