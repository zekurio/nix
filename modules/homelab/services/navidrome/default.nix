{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.navidrome;
    mediaShare = config.modules.homelab.mediaShare;
    domain = "music.${config.services.homelab.domains.zekurio}";
    port = 4533;
  in {
    options.services.homelab.navidrome.enable = lib.mkEnableOption "Navidrome music server with Caddy integration";

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = mediaShare.enable;
          message = "Navidrome requires the shared music directory and group.";
        }
      ];

      services.navidrome = {
        enable = true;
        openFirewall = false;
        settings = {
          Address = "127.0.0.1";
          Port = port;
          MusicFolder = mediaShare.musicDir;
          "Scanner.Schedule" = "@every 5m";
          # Beets maintains the covers; external album art can select another release.
          CoverArtPriority = "cover.*, folder.*, front.*, embedded";
        };
      };

      systemd.services.navidrome = {
        unitConfig.RequiresMountsFor = [mediaShare.musicDir];
        # The upstream module bind-mounts MusicFolder read-only in its sandbox.
        serviceConfig.SupplementaryGroups = [mediaShare.group];
      };

      services.homelab.caddy.virtualHosts.navidrome = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
