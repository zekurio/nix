{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    ...
  }: let
    cfg = config.services.homelab.droppedneedle;
    mediaShare = config.modules.homelab.mediaShare;
    domain = "music.${config.services.homelab.domains.zekurio}";
    port = 8688;
    slskdDownloadsDir = "${mediaShare.downloadsRoot}/complete/slskd";
  in {
    imports = [inputs.droppedneedle.nixosModules.default];

    options.services.homelab.droppedneedle = {
      enable = lib.mkEnableOption "DroppedNeedle music server with Caddy and media-share integration";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !config.services.homelab.beets.enable;
          message = "Disable Beets so it cannot import downloads before DroppedNeedle verifies them.";
        }
        {
          assertion = mediaShare.enable;
          message = "services.homelab.droppedneedle requires modules.homelab.mediaShare.";
        }
        {
          assertion = config.services.homelab.slskd.enable;
          message = "services.homelab.droppedneedle requires services.homelab.slskd for its download pipeline.";
        }
      ];

      services.droppedneedle = {
        enable = true;
        inherit port;
        mediaDirectories = [
          mediaShare.musicDir
          slskdDownloadsDir
        ];
        supplementaryGroups = [mediaShare.group];
        umask = mediaShare.umask;
        environment = {
          SLSKD_DOWNLOADS_PATH = slskdDownloadsDir;
          TZ = config.time.timeZone;
        };
      };

      systemd.services.droppedneedle = {
        wants = ["slskd.service"];
        after = ["slskd.service"];
        unitConfig.RequiresMountsFor = [
          mediaShare.musicDir
          slskdDownloadsDir
        ];
      };

      services.homelab.caddy.virtualHosts.droppedneedle = {
        inherit domain;
        # DroppedNeedle provides its own login and app passwords. Public access
        # is also required by OpenSubsonic clients.
        public = true;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
