{
  flake.modules.nixos.lilith = {pkgs, ...}: {
    services.tailscale = {
      enable = true;
      # UDP 41641 inbound lets peers connect directly instead of falling
      # back to DERP relays.
      openFirewall = true;
      # Linux rejects advertised subnet routes by default. Flint provides
      # both the 10.0.0.0/24 route and tailnet DNS.
      useRoutingFeatures = "client";
      extraSetFlags = [
        "--accept-dns=true"
        "--accept-routes=true"
        "--hostname=lilith"
      ];
    };

    environment.systemPackages = [pkgs.tailscale-systray];
  };
}
