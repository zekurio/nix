{inputs, ...}: {
  flake.modules.nixos.gaming = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
    chaoticPkgs = inputs.chaotic.legacyPackages.${system};

    # Chaotic's release wrappers predate nixpkgs' dedicated steamcompattool
    # output. Adapt their official-release payloads to the contract expected by
    # programs.steam.extraCompatPackages without rebuilding either Proton.
    mkSteamCompatTool = name: source:
      pkgs.runCommand "${name}-${source.version}" {
        outputs = [
          "out"
          "steamcompattool"
        ];
        preferLocalBuild = true;
        allowSubstitutes = false;
      } ''
        mkdir -p "$out" "$steamcompattool"
        ln -s ${source}/bin/* "$steamcompattool/"
        ln -s "$steamcompattool" "$out/${name}"
      '';

    protonGe = mkSteamCompatTool "proton-ge-custom" chaoticPkgs.proton-ge-custom;
    protonCachyos = mkSteamCompatTool "proton-cachyos-x86-64-v3" chaoticPkgs.proton-cachyos_x86_64_v3;
    heroic = pkgs.heroic.override {
      extraPkgs = pkgs':
        with pkgs'; [
          gamemode
          mangohud
        ];
    };
  in {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    programs = {
      steam = {
        enable = true;
        extraPackages = [pkgs.mangohud];
        extraCompatPackages = [
          protonGe
          protonCachyos
        ];
        protontricks.enable = true;
      };
      gamemode.enable = true;
    };

    environment.systemPackages = [
      heroic
      pkgs.mangohud
    ];

    home-manager.users.zekurio = {
      programs.mangohud = {
        enable = true;
        enableSessionWide = false;
      };
      catppuccin.mangohud.enable = true;
    };
  };
}
