{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.gaming;
  system = pkgs.stdenv.hostPlatform.system;
  chaoticPkgs = inputs.chaotic.legacyPackages.${system};

  # Chaotic builds proton-cachyos-bin_x86_64_v3 from its deprecated
  # proton-cachyos alias, which warns on every evaluation and fails CI's
  # abort-on-warn. The same override from the new name gives the identical
  # derivation. Once Chaotic's overlay stops using the alias, use
  # chaoticPkgs.proton-cachyos-bin_x86_64_v3 directly.
  aliasedUpstream =
    lib.hasInfix "proton-cachyos-bin_x86_64_v3 = final.proton-cachyos.override"
    (builtins.readFile "${inputs.chaotic}/overlays/default.nix");
  protonCachyos =
    lib.warnIf (!aliasedUpstream)
    "modules/nixos/gaming/default.nix: Chaotic no longer builds proton-cachyos-bin_x86_64_v3 from its alias; use it directly and drop this workaround."
    (chaoticPkgs.proton-cachyos-bin_edge.override {
      toolTitle = "Proton-CachyOS x86-64-v3";
      toolArch = "x86_64_v3";
      tarballSuffix = "-x86_64_v3.tar.xz";
      manifestFilename = "cachyos-v3-manifest.json";
    });

  heroic = pkgs.heroic.override {
    extraPkgs = pkgs':
      with pkgs'; [
        gamemode
        mangohud
      ];
  };
in {
  options.modules.gaming.enable = lib.mkEnableOption "the desktop gaming stack";

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    programs = {
      steam = {
        enable = true;
        extraPackages = [pkgs.mangohud];
        # Chaotic's package has its own steamcompattool output with a real
        # (not symlinked) compatibilitytool.vdf, which current Steam needs.
        extraCompatPackages = [protonCachyos];
        protontricks.enable = true;
      };
      gamemode.enable = true;
    };

    environment.systemPackages = [
      # nixpkgs patches in a dialog on every launch saying the package is
      # unofficial and bugs belong on the nixpkgs tracker.
      (pkgs.bottles.override {removeWarningPopup = true;})
      heroic
      pkgs.mangohud
      pkgs.r2modman
    ];

    users.users.zekurio.extraGroups = ["gamemode"];

    home-manager.users.zekurio = {
      programs.mangohud = {
        enable = true;
        enableSessionWide = false;
        settings = {
          frametime = true;
          gpu_core_clock = true;
          gpu_mem_clock = true;
          ram = true;
          vram = true;
        };
      };
    };
  };
}
