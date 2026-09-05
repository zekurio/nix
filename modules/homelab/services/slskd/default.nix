{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.slskd;
    downloadsRoot = config.modules.homelab.mediaShare.downloadsRoot;
    domain = "admin.${config.services.homelab.domains.zekurio}";
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
            # Without a retention interval slskd only indexes shares at
            # startup. DroppedNeedle imports into this tree continuously, so
            # the index would otherwise go stale and advertise less than we
            # hold. Soulseek peers can withhold search results from users who
            # share nothing, which silently breaks acquisition.
            cache.retention = 360;
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
            # App-native login is provisioned from the shared admin password;
            # the vhost on the admin domain is LAN/tailnet-only.
            authentication.disabled = false;
          };
          logger.disk = false;
        };
      };

      sops = {
        secrets = {
          slskd_env = {
            owner = "slskd";
            group = "slskd";
            mode = "0400";
          };
          slskd_api_key = {};
        };
        templates."slskd-api.env" = {
          content = ''
            SLSKD_API_KEY=${config.sops.placeholder.slskd_api_key}
          '';
          owner = "slskd";
          group = "slskd";
          mode = "0400";
          restartUnits = ["slskd.service"];
        };
      };

      systemd.tmpfiles.rules = [
        "z ${profilePicture} 0644 slskd slskd -"
      ];

      systemd.services.slskd.serviceConfig = {
        EnvironmentFile = lib.mkAfter [config.sops.templates."slskd-api.env".path];
        SupplementaryGroups = [mediaShare.group];
        UMask = lib.mkForce mediaShare.umask;
      };

      # The whole admin domain is LAN/tailnet-only, so no per-path source
      # restriction is needed here.
      services.homelab.caddy.virtualHosts."slskd" = {
        inherit domain;
        extraConfig = ''
          redir /slskd /slskd/

          # slskd's packaged index keeps the same size and timestamp across
          # some upgrades, so Kestrel can reuse its metadata-based ETag even
          # when the hashed JS and CSS asset names changed. Force the index to
          # refresh or browsers keep stale HTML that points at removed assets.
          @slskd_index path /slskd/
          request_header @slskd_index -If-None-Match
          request_header @slskd_index -If-Modified-Since
          header @slskd_index {
            Cache-Control "no-store"
            -ETag
            -Last-Modified
          }

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
