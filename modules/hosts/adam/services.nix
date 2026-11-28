{
  modules.virtualization.enable = true;

  services.homelab = {
    alloy.enable = true;
    anvil.enable = true;
    atuin-ai.enable = true;
    aurral.enable = true;
    blitzcrank = {
      enable = true;
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
    coolercontrol.enable = true;
    fluxer.enable = true;
    immich.enable = true;
    knot.enable = true;
    matinee.enable = true;
    mediaCleanup.enable = true;
    orianna.enable = true;
    pocket-id.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    sabnzbd.enable = true;
    slskd.enable = true;
    sonarr.enable = true;
    t3code.enable = true;
    vrouter.enable = true;
    wealthfolio.enable = true;
  };
}
