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

  nixpkgs.config.permittedInsecurePackages = [
    "electron-36.9.5"
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = ["en_US.UTF-8/UTF-8"];
  };
}
