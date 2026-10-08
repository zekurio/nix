{
  flake.modules.nixos.adam = {
    config,
    lib,
    pkgs,
    ...
  }: let
    plugin = pkgs.fetchurl {
      url = "https://github.com/Akoozie/ValheimTune/releases/download/v0.7.9/ValheimTune.dll";
      hash = "sha256-jgDHFHaAarjtbjRKpjnLCNXZ606Q06fHfk3i8LZ8W5o=";
    };
    # Only tune delivery capacity and frame cadence. Keep the plugin's optional
    # object selection, save changes and cleanup disabled.
    settings = pkgs.writeText "akoozie.valheimtune.cfg" ''
      [Measure]
      LogIntervalSeconds = 30
      ConfigReloadSeconds = 5

      [Server]
      TargetFrameRate = 60
      DeferAssetUnload = false
      SkipRenderMesh = false

      [Sync]
      OverrideSendWindow = true
      SendWindowBytes = 32768
      MinHeadroomBytes = 4096
      AllPeersPerRound = false
      DirtySets = false
      TopKSort = false
      RelayMinIntervalMs = 0

      [Steam]
      OverrideSendRate = true
      SendRateMinBytesPerSec = 153600
      SendRateMaxBytesPerSec = 524288

      [Receive]
      MaxPacketsPerPeerPerFrame = 0

      [Fixes]
      SaveDirtyFix = false
      SpawnerLinkFix = false
      DeadZdoPrune = false
      DisconnectNoSleep = false
      GlobalKeyDedupe = false

      [Cleanup]
      FloatingDropsRun = false
      FloatingDropsDelete = false

      [Compat]
      DisableOnUnknownBuild = true
    '';
  in {
    systemd.services.podman-valheim = lib.mkIf config.services.homelab.valheim.enable {
      # The container copies plugins from this persistent directory on startup.
      preStart = lib.mkBefore ''
        ${pkgs.coreutils}/bin/install -D -o 1000 -g 1000 -m 0644 ${plugin} \
          /var/lib/valheim/config/valheimplus/plugins/ValheimTune.dll
        ${pkgs.coreutils}/bin/install -D -o 1000 -g 1000 -m 0644 ${settings} \
          /var/lib/valheim/config/valheimplus/akoozie.valheimtune.cfg
      '';
    };
  };
}
