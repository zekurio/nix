{
  modules.virtualization.enable = true;

  services.homelab = {
    alloy.enable = true;
    atuin-ai.enable = true;
    aurral = {
      enable = true;
      oidc.enable = true;
    };
    blitzcrank = {
      enable = true;
      discord = {
        enable = true;
        channels = ["1511015305592443001"];
        allowedUsers = ["144853050761150465"];
        triageModel = "openrouter/typesafe/jev-1.14";
      };
      fluxer = {
        enable = true;
        # #support in the single community.
        channels = ["1564016936159805440"];
        allowedUsers = ["1563624022032252928"];
        triageModel = "openrouter/typesafe/jev-1.14";
      };
    };
    blitzcrank-mcp.enable = true;
    configarr.enable = true;
    beszel.enable = true;
    copyparty.enable = true;
    coolercontrol.enable = true;
    fluxer.enable = true;
    immich.enable = true;
    jellyfin.enable = true;
    inviterr.enable = true;
    mediaCleanup.enable = true;
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
}
