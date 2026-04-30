{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkAfter mkDefault;
in {
  imports = [
    ../../user.nix
    ../../shell
    ../../dev
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

  hardware.enableRedistributableFirmware = mkDefault true;
  hardware.firmware = mkDefault [pkgs.linux-firmware];

  boot.kernelParams = mkAfter ["microcode.amd_sha_check=off"];

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
      trusted-users = [
        "root"
        "@wheel"
      ];
      substituters = [
        "https://cache.nixos.org/"
        "https://cache.numtide.com"
        "https://cachix.cachix.org"
        "https://nixpkgs.cachix.org"
        "https://nix-community.cachix.org"
        "https://cache.garnix.io"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
        "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
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
