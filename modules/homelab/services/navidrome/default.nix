{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    domain = "music.${config.services.homelab.domains.zekurio}";
    port = 4533;
    musicDir = config.modules.homelab.mediaShare.musicDir;
  in {
    options.services.homelab.navidrome = {
      enable = lib.mkEnableOption "Navidrome music streaming server with Caddy integration";
    };

    config = lib.mkIf config.services.homelab.navidrome.enable {
      services.navidrome = {
        enable = true;
        settings = {
          # Aurral talks to Navidrome from a podman bridge network, so loopback
          # is not reachable. The firewall only opens this port on podman0, and
          # public access still goes through Caddy.
          Address = "0.0.0.0";
          Port = port;
          MusicFolder = musicDir;
          EnableInsightsCollector = false;
          ScanSchedule = "1h";
        };
      };

      users.users.navidrome.extraGroups = ["share"];

      services.homelab.caddy.virtualHosts."navidrome" = {
        inherit domain;
        # Navidrome owns the root of the music domain and keeps its own auth:
        # Subsonic clients cannot complete an OIDC flow, so no gating here.
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
