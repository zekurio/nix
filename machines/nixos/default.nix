{lib, ...}: let
  inherit (lib) mkDefault;
in {
  imports = [
    ../../modules/users
    ../../modules/virtualization
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = ["en_US.UTF-8/UTF-8"];
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  programs.nix-ld.enable = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = true;
    };

    gc = {
      automatic = mkDefault true;
      dates = mkDefault "weekly";
      options = mkDefault "--delete-older-than 7d";
    };
  };
}
