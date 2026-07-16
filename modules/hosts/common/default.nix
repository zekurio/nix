{
  flake.modules.nixos.base = {
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkDefault;
  in {
    modules.ssh.users = ["zekurio"];

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
    hardware.firmware = mkDefault [pkgs.linux-firmware];

    programs.nix-ld.enable = true;

    security.sudo.extraRules = [
      {
        users = ["zekurio"];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

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
        inherit (import ../../_caches.nix) substituters trusted-public-keys;
        auto-optimise-store = true;
      };

      gc = {
        automatic = mkDefault true;
        dates = mkDefault "weekly";
        options = mkDefault "--delete-older-than 7d";
      };
    };

    time.timeZone = "Europe/Vienna";
  };
}
