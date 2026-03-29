{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.slskd;
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
  shareUser = "share";
  shareGroup = "share";
  queueDir = "/var/lib/slskd-beets-queue";
  queuePendingDir = "${queueDir}/pending";
  queueProcessingDir = "${queueDir}/processing";
  queueFailedDir = "${queueDir}/failed";
  importDebounceSeconds = 45;
  beetsImportCommand =
    if config.services.homelab.beets.enable
    then config.services.homelab.beets.importCommand
    else "${pkgs.coreutils}/bin/false";

  fixMusicPermissionsScript = pkgs.writeShellScript "slskd-fix-music-permissions" ''
    set -eu

    ${pkgs.findutils}/bin/find ${musicDir} -type d -exec ${pkgs.coreutils}/bin/chmod 2775 {} +
    ${pkgs.findutils}/bin/find ${musicDir} -type f ! -perm -g+r -exec ${pkgs.coreutils}/bin/chmod g+r {} +
  '';

  queueBeetsImportScript = pkgs.writeShellScript "slskd-queue-beets-import" ''
        set -eu

        payload=''${SLSKD_SCRIPT_DATA-}
        if [ -z "$payload" ]; then
          exit 0
        fi

        download_file="$(${pkgs.jq}/bin/jq -r '
          [
            .. | objects | (
              .filename?,
              .Filename?,
              .localFilename?,
              .local_filename?,
              .path?,
              .Path?,
              .targetFilename?,
              .TargetFilename?
            )
          ]
          | map(select(type == "string" and . != ""))
          | first // empty
        ' <<EOF
    $payload
    EOF
    )"

        if [ -z "$download_file" ]; then
          exit 0
        fi

        download_dir="$(${pkgs.coreutils}/bin/dirname "$download_file")"
        marker_name="$(${pkgs.coreutils}/bin/printf '%s' "$download_dir" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.gawk}/bin/awk '{print $1}')"
        tmp_marker="$(${pkgs.coreutils}/bin/mktemp "${queuePendingDir}/.$marker_name.XXXXXX")"

        ${pkgs.coreutils}/bin/printf '%s\n' "$download_dir" > "$tmp_marker"
        ${pkgs.coreutils}/bin/chmod 0664 "$tmp_marker"
        ${pkgs.coreutils}/bin/mv "$tmp_marker" "${queuePendingDir}/$marker_name"
  '';

  importQueuedBeetsScript = pkgs.writeShellScript "slskd-import-queued-beets" ''
    set -eu

    ${pkgs.coreutils}/bin/sleep ${toString importDebounceSeconds}

    shopt -s nullglob
    for marker in ${queuePendingDir}/*; do
      [ -f "$marker" ] || continue

      marker_name="$(${pkgs.coreutils}/bin/basename "$marker")"
      processing_marker="${queueProcessingDir}/$marker_name"

      if ! ${pkgs.coreutils}/bin/mv "$marker" "$processing_marker" 2>/dev/null; then
        continue
      fi

      download_path="$(${pkgs.coreutils}/bin/cat "$processing_marker")"

      if [ -z "$download_path" ] || [ ! -d "$download_path" ]; then
        ${pkgs.coreutils}/bin/mv "$processing_marker" "${queueFailedDir}/$marker_name"
        continue
      fi

      if ${beetsImportCommand} "$download_path"; then
        ${pkgs.coreutils}/bin/rm -f "$processing_marker"
        continue
      fi

      ${pkgs.coreutils}/bin/mv "$processing_marker" "${queueFailedDir}/$marker_name"
    done
  '';
in {
  options.services.homelab.slskd = {
    enable = lib.mkEnableOption "slskd Soulseek client with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.homelab.beets.enable;
        message = "services.homelab.slskd requires services.homelab.beets to be enabled for automatic imports.";
      }
    ];

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
        integration.scripts.beets_import = {
          on = ["DownloadFileComplete"];
          run.executable = queueBeetsImportScript;
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
          authentication.disabled = true;
        };
      };
    };

    # Ensure profile picture is readable by slskd
    systemd.tmpfiles.rules = [
      "z ${profilePicture} 0644 ${config.services.slskd.user} ${config.services.slskd.group} -"
      "d ${queueDir} 2775 ${shareUser} ${shareGroup} -"
      "d ${queuePendingDir} 2775 ${config.services.slskd.user} ${shareGroup} -"
      "d ${queueProcessingDir} 2775 ${shareUser} ${shareGroup} -"
      "d ${queueFailedDir} 2775 ${shareUser} ${shareGroup} -"
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
        queueDir
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

    systemd.paths.slskd-beets-import = {
      wantedBy = ["multi-user.target"];
      pathConfig = {
        DirectoryNotEmpty = queuePendingDir;
        PathModified = queuePendingDir;
      };
    };

    systemd.services.slskd-beets-import = {
      description = "Import completed slskd downloads into beets";
      serviceConfig = {
        Type = "oneshot";
        User = shareUser;
        Group = shareGroup;
        UMask = "0002";
        ExecStart = importQueuedBeetsScript;
        ReadWritePaths = [
          queueDir
          downloadDir
          musicDir
          beetsDir
        ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

    # SOPS secret for slskd credentials
    sops.secrets.slskd_env = {
      owner = config.services.slskd.user;
      group = config.services.slskd.group;
      mode = "0400";
    };

    # Caddy reverse proxy
    services.homelab.caddy.virtualHosts."slskd" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4181";
      reverseProxy = "127.0.0.1:${toString webPort}";
    };
  };
}
