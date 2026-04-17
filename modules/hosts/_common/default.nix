{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault;
in {
  imports = [
    ../../user.nix
    ../../shell
    ../../dev
    ../../desktop
    ../../gaming.nix
    ../../virtualization.nix
  ];

  modules = {
    shell.enable = mkDefault true;
    dev.enable = mkDefault true;
  };

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

  nixpkgs.config = {
    allowUnfree = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    firmware = [pkgs.linux-firmware];
  };

  programs.nix-ld.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-substituters = [
        "https://cache.numtide.com"
      ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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

  time.timeZone = "Europe/Vienna";
}
