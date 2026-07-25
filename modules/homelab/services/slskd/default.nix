{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.slskd;
    downloadsRoot = config.modules.homelab.mediaShare.downloadsRoot;
    domain = "music.${config.services.homelab.domains.zekurio}";
    webPort = 5030;
    listenPort = 50300;
    mediaShare = config.modules.homelab.mediaShare;
    musicDir = mediaShare.musicDir;
    downloadsDir = "${downloadsRoot}/complete/slskd";
    incompleteDir = "${downloadsRoot}/incomplete/slskd";
    profilePicture = "/var/lib/slskd/profile.jpg";
  in {
    options.services.homelab.slskd = {
      enable = lib.mkEnableOption "slskd Soulseek daemon with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      services.slskd = {
        enable = true;
        environmentFile = config.sops.secrets.slskd_env.path;
        openFirewall = true;
        settings = {
          flags.force_share_scan = true;
          rooms = [];
          filters.search.request = [];
          global = {
            upload = {
              slots = 30;
              speed_limit = 4096;
            };
            download = {
              slots = 500;
              speed_limit = 32768;
            };
          };
          retention = {
            transfers = {
              upload = {
                succeeded = 2880;
                errored = 2880;
                cancelled = 2880;
              };
              download = {
                succeeded = 2880;
                errored = 2880;
                cancelled = 2880;
              };
            };
            files = {
              complete = 20160;
              incomplete = 1440;
            };
          };
          directories = {
            downloads = downloadsDir;
            incomplete = incompleteDir;
          };
          shares = {
            directories = [musicDir];
            filters = [
              "\\.DS_Store$"
              "Thumbs.db$"
              "\\.ini$"
            ];
          };
          soulseek = {
            listen_port = listenPort;
            picture = profilePicture;
            description = "new to soulseek. sharing what I have. if something does not work/is locked let me know.";
          };
          web = {
            port = webPort;
            url_base = "/slskd";
            https.disabled = true;
            authentication.disabled = true;
          };
          logger.disk = false;
        };
      };

      sops.secrets.slskd_env = {
        owner = "slskd";
        group = "slskd";
        mode = "0400";
      };

      systemd.tmpfiles.rules = [
        "z ${profilePicture} 0644 slskd slskd -"
      ];

      systemd.services.slskd.serviceConfig = {
        SupplementaryGroups = [mediaShare.group];
        UMask = lib.mkForce mediaShare.umask;
      };

      services.homelab.caddy.virtualHosts."slskd" = {
        inherit domain;
        # Gate only /slskd*: Navidrome shares this domain at the root and must
        # stay reachable for Subsonic clients.
        forwardAuth = config.services.homelab.oauth2-proxy.zekurio.forwardAuthAddress;
        authPaths = ["/slskd*"];
        extraConfig = ''
          redir /slskd /slskd/
          @slskd path /slskd*
          reverse_proxy @slskd 127.0.0.1:${toString webPort} {
            header_up Host {http.request.host}
            header_up X-Forwarded-Prefix /slskd
          }
        '';
      };
    };
  };
}
