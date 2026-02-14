{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.slskd-wrapped;
  domain = "slskd.zekurio.xyz";
  webPort = 5030;
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

  # Import script triggered by slskd on download completion
  beetImportScript = pkgs.writeShellScript "slskd-beet-import" ''
    BEETSDIR=${beetsDir} ${lib.getExe pkgs.beets} -c ${config.services.beets-wrapped.configFile} import ${downloadDir}
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
        # Upstream NixOS module declares typed options without defaults,
        # which breaks nix eval. Set sensible defaults here.
        flags.force_share_scan = false;
        rooms = [];
        filters.search.request = [];
        global = {
          upload = {
            slots = 20;
            speed_limit = 10000;
          };
          download = {
            slots = 500;
            speed_limit = 10000;
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
          description = "new to soulseek. sharing what I have. most is ripped from tidal/deezer or torrents.";
          picture = profilePicture;
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
        # Run beets import on download completion
        integration.scripts.beet-import = {
          on = [
            "DownloadDirectoryComplete"
            "DownloadFileComplete"
          ];
          run = {
            executable = "${pkgs.bash}/bin/bash";
            command = "-c ${beetImportScript}";
          };
        };
        web = {
          port = webPort;
          https.disabled = true;
        };
      };
    };

    # Upstream slskd makes shared paths read-only; clear that so beets import can move files into musicDir
    systemd.services.slskd.serviceConfig = {
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
      reverseProxy = "127.0.0.1:${toString webPort}";
    };
  };
}
