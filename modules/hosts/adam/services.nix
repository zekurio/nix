{
  modules.virtualization.enable = true;

  services.homelab = {
    alloy.enable = true;
    atuin-ai.enable = true;
    # Off until the overhaul: Seerr, its only mandatory backend, is off
    # while Matinee replaces the Jellyfin stack. Fluxer is off too because
    # it asserts Blitzcrank itself.
    blitzcrank = {
      enable = false;
      fluxer = {
        enable = false;
        # #support in the single community.
        channels = ["1564016936159805440"];
        allowedUsers = ["1563624022032252928"];
        triageModel = "openrouter/typesafe/jev-1.14";
      };
    };
    blitzcrank-mcp.enable = false;
    configarr.enable = true;
    coolercontrol.enable = true;
    fluxer.enable = true;
    immich.enable = true;
    knot.enable = true;
    matinee.enable = true;
    mediaCleanup.enable = true;
    navidrome.enable = true;
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
