{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.slskd-wrapped;
  domain = "slskd.zekurio.xyz";
  webPort = 5030;
  listenPort = 50300;
  socksAddress = "10.100.0.1";
  socksPort = 1080;
  musicDir = "/tank/media/music";
  downloadDir = "/mnt/downloads/complete/slskd";
  incompleteDir = "/mnt/downloads/incomplete/slskd";
  profilePicture = "/var/lib/slskd/profile.jpg";
  beetsDir = "/var/lib/beets";

  fixMusicPermissionsScript = pkgs.writeShellScript "slskd-fix-music-permissions" ''
    set -eu

    ${pkgs.findutils}/bin/find ${musicDir} -type d -exec ${pkgs.coreutils}/bin/chmod 2775 {} +
    ${pkgs.findutils}/bin/find ${musicDir} -type f ! -perm -g+r -exec ${pkgs.coreutils}/bin/chmod g+r {} +
  '';
in {
  options.services.slskd-wrapped = {
    enable = lib.mkEnableOption "slskd Soulseek client with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    services.slskd = {
      enable = true;
      openFirewall = true;
      domain = null;
      environmentFile = config.sops.secrets.slskd_env.path;
      settings = {
        flags.force_share_scan = false;
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

        soulseek = {
          description = "new to soulseek. sharing what I have. if something does not work/is locked let me know.";
          picture = profilePicture;
          listen_port = listenPort;
          # Route all Soulseek connections through VPS so the server sees VPS IP
          connection.proxy = {
            enabled = true;
            address = socksAddress;
            port = socksPort;
          };
        };
        directories = {
          downloads = downloadDir;
          incomplete = incompleteDir;
        };
        shares = {
          directories = [musicDir];
          filters = [
            "\\.ini$"
            "Thumbs.db$"
            "\\.DS_Store$"
          ];
        };
        web = {
          port = webPort;
          https.disabled = true;
        };
      };
    };

    # Ensure profile picture is readable by slskd
    systemd.tmpfiles.rules = [
      "z ${profilePicture} 0644 ${config.services.slskd.user} ${config.services.slskd.group} -"
    ];

    # Upstream slskd makes shared paths read-only; clear that so beets import can move files into musicDir
    systemd.services.slskd.serviceConfig = {
      UMask = "0002";
      ReadOnlyPaths = lib.mkForce [];
      ReadWritePaths = [
        musicDir
        downloadDir
        incompleteDir
        beetsDir
      ];
    };

    # Ensure files in shared music tree stay readable for slskd uploads
    systemd.services.slskd-fix-music-permissions = {
      description = "Fix shared music permissions for slskd";
      before = ["slskd.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = fixMusicPermissionsScript;
      };
    };

    systemd.timers.slskd-fix-music-permissions = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    systemd.services.slskd = {
      wants = ["slskd-fix-music-permissions.service"];
      after = ["slskd-fix-music-permissions.service"];
    };

    # SOPS secret for slskd credentials
    sops.secrets.slskd_env = {
      owner = config.services.slskd.user;
      group = config.services.slskd.group;
      mode = "0400";
    };

    # Caddy reverse proxy
    services.caddy-wrapper.virtualHosts."slskd" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4181";
      reverseProxy = "127.0.0.1:${toString webPort}";
    };
  };
}
