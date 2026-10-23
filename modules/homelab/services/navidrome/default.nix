{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.navidrome;
    mediaShare = config.services.homelab.mediaShare;
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
        # Supplies ND_LASTFM_APIKEY and ND_LASTFM_SECRET. Navidrome ships no
        # Last.fm key and leaves scrobbling off unless both are set.
        environmentFile = config.sops.secrets.navidrome_env.path;
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

      sops.secrets.navidrome_env = {
        owner = config.services.navidrome.user;
        group = config.services.navidrome.group;
        mode = "0400";
        # EnvironmentFile is read once at start, so a rotated key would
        # otherwise stay unused until an unrelated restart.
        restartUnits = ["navidrome.service"];
      };

      services.homelab.backup = {
        stopUnits = ["navidrome.service"];
        # Resized images and transcodes, the upstream module's default
        # location. The artwork folder is not a cache: the database points at
        # the images Navidrome acquired there.
        exclude = ["${config.services.navidrome.settings.CacheFolder or "/var/lib/navidrome/cache"}/"];
      };

      services.homelab.caddy.virtualHosts.navidrome = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
        # Subsonic clients cannot do SSO, so Navidrome's own login guards the
        # public vhost.
        public = true;
      };
    };
  };
}
