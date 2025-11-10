{lib, ...}: {
  imports = [];

  # Common Nix configuration
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkForce "--delete-older-than 7d";
    };
    settings = {
      auto-optimise-store = true;
    };
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = ["en_US.UTF-8/UTF-8"];
  };
}
