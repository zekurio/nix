{
  flake.modules.nixos.adam = {
    modules.virtualization.enable = true;

    services.homelab = {
      alloy.enable = true;
      aurral.enable = true;
      blitzcrank = {
        enable = true;
        discord = {
          enable = true;
          channels = ["1511015305592443001"];
          allowedUsers = ["144853050761150465"];
          triageModel = "openrouter/typesafe/jev-1.14";
        };
      };
      blitzcrank-mcp.enable = true;
      configarr.enable = true;
      beets.enable = true;
      copyparty.enable = true;
      coolercontrol.enable = true;
      fluxer.enable = true;
      immich.enable = true;
      jellyfin.enable = true;
      inviterr.enable = true;
      lidarr.enable = true;
      mediaCleanup.enable = true;
      navidrome.enable = true;
      pocket-id.enable = true;
      prowlarr.enable = true;
      radarr.enable = true;
      sabnzbd.enable = true;
      seerr.enable = true;
      slskd.enable = true;
      sonarr.enable = true;
      t3code.enable = true;
      vrouter.enable = true;
      windrose = {
        enable = false;
        maxPlayers = 4;
        hostNetwork = true;
        p2pProxyAddress = "10.0.0.2";
      };
    };
  };
}
