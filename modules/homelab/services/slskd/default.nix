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
  musicDir = "/tank/media/music";
  downloadDir = "/var/lib/downloads/complete/slskd";
  incompleteDir = "/var/lib/downloads/incomplete/slskd";
  profilePicture = "/var/lib/slskd/profile.jpg";
  beetsDir = "/var/lib/beets";
  shareUser = "share";
  shareGroup = "share";
  queueDir = "/var/lib/slskd-beets-queue";
  queuePendingDir = "${queueDir}/pending";
  queueProcessingDir = "${queueDir}/processing";
  queueDeferredDir = "${queueDir}/deferred";
  queueFailedDir = "${queueDir}/failed";
  importDebounceSeconds = 45;
  failedTransferStates = [
    80 # Completed | Cancelled
    144 # Completed | TimedOut
    272 # Completed | Errored
    528 # Completed | Rejected
    1040 # Completed | Aborted
  ];
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

    event_type="$(${pkgs.coreutils}/bin/printf '%s' "$payload" | ${pkgs.jq}/bin/jq -r '.type // .Type // empty')"

    if [ "$event_type" != "DownloadDirectoryComplete" ]; then
      exit 0
    fi

    download_dir="$(${pkgs.coreutils}/bin/printf '%s' "$payload" | ${pkgs.jq}/bin/jq -r '
      [
        .localDirectoryName?,
        .LocalDirectoryName?
      ]
      | map(select(type == "string" and . != ""))
      | first // empty
    ')"

    remote_dir="$(${pkgs.coreutils}/bin/printf '%s' "$payload" | ${pkgs.jq}/bin/jq -r '
      [
        .remoteDirectoryName?,
        .RemoteDirectoryName?
      ]
      | map(select(type == "string" and . != ""))
      | first // empty
    ')"

    username="$(${pkgs.coreutils}/bin/printf '%s' "$payload" | ${pkgs.jq}/bin/jq -r '
      [
        .username?,
        .Username?
      ]
      | map(select(type == "string" and . != ""))
      | first // empty
    ')"

    if [ -z "$download_dir" ]; then
      exit 0
    fi

    download_dir="$(${pkgs.coreutils}/bin/realpath -m "$download_dir")"
    case "$download_dir" in
      ${downloadDir}/*) ;;
      *) exit 0 ;;
    esac

    [ -d "$download_dir" ] || exit 0

    marker_name="$(${pkgs.coreutils}/bin/printf '%s' "$download_dir" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.gawk}/bin/awk '{print $1}')"
    tmp_marker="$(${pkgs.coreutils}/bin/mktemp "${queuePendingDir}/.$marker_name.XXXXXX")"

    ${pkgs.jq}/bin/jq -n \
      --arg downloadPath "$download_dir" \
      --arg username "$username" \
      --arg remoteDirectoryName "$remote_dir" \
      '{
        downloadPath: $downloadPath,
        username: $username,
        remoteDirectoryName: $remoteDirectoryName
      }' > "$tmp_marker"
    ${pkgs.coreutils}/bin/chmod 0664 "$tmp_marker"
    ${pkgs.coreutils}/bin/mv "$tmp_marker" "${queuePendingDir}/$marker_name"
  '';

  importQueuedBeetsScript = pkgs.writeShellScript "slskd-import-queued-beets" ''
    set -eu

    ${pkgs.coreutils}/bin/sleep ${toString importDebounceSeconds}

    failed_states='${lib.concatMapStringsSep " " toString failedTransferStates}'

    has_failed_downloads() {
      username="$1"
      remote_dir="$2"

      [ -n "$username" ] || return 1
      [ -n "$remote_dir" ] || return 1

      response="$(${pkgs.curl}/bin/curl -fsS --max-time 10 "http://127.0.0.1:${toString webPort}/api/v0/transfers/downloads?includeRemoved=true")" || return 0

      failed_count="$(${pkgs.coreutils}/bin/printf '%s' "$response" | ${pkgs.jq}/bin/jq -r \
        --arg username "$username" \
        --arg remote_dir "$remote_dir" \
        --argjson failed_states "[${lib.concatMapStringsSep ", " toString failedTransferStates}]" \
        '
          [
            .[]
            | select(.username == $username)
            | .directories[]?
            | select(.directory == $remote_dir)
            | .files[]?
            | select(
                (.state | tonumber? as $state | $failed_states | index($state))
                or
                (.state | tostring | test("Cancelled|TimedOut|Errored|Rejected|Aborted"))
              )
          ]
          | length
        ')" || return 0

      [ "$failed_count" -gt 0 ]
    }

    process_markers() {
      source_dir="$1"

      shopt -s nullglob
      for marker in "$source_dir"/*; do
        [ -f "$marker" ] || continue

        marker_name="$(${pkgs.coreutils}/bin/basename "$marker")"
        processing_marker="${queueProcessingDir}/$marker_name"

        if ! ${pkgs.coreutils}/bin/mv "$marker" "$processing_marker" 2>/dev/null; then
          continue
        fi

        marker_payload="$(${pkgs.coreutils}/bin/cat "$processing_marker")"
        if ${pkgs.coreutils}/bin/printf '%s' "$marker_payload" | ${pkgs.jq}/bin/jq -e 'type == "object"' >/dev/null 2>&1; then
          download_path="$(${pkgs.coreutils}/bin/printf '%s' "$marker_payload" | ${pkgs.jq}/bin/jq -r '.downloadPath // empty')"
          username="$(${pkgs.coreutils}/bin/printf '%s' "$marker_payload" | ${pkgs.jq}/bin/jq -r '.username // empty')"
          remote_dir="$(${pkgs.coreutils}/bin/printf '%s' "$marker_payload" | ${pkgs.jq}/bin/jq -r '.remoteDirectoryName // empty')"
        else
          download_path="$marker_payload"
          username=
          remote_dir=
        fi

        if [ -z "$download_path" ] || [ ! -d "$download_path" ]; then
          ${pkgs.coreutils}/bin/mv "$processing_marker" "${queueFailedDir}/$marker_name"
          continue
        fi

        if has_failed_downloads "$username" "$remote_dir"; then
          ${pkgs.coreutils}/bin/mv "$processing_marker" "${queueDeferredDir}/$marker_name"
          continue
        fi

        if ${beetsImportCommand} "$download_path"; then
          ${pkgs.coreutils}/bin/rm -f "$processing_marker"
          continue
        fi

        ${pkgs.coreutils}/bin/mv "$processing_marker" "${queueFailedDir}/$marker_name"
      done
    }

    process_markers ${queuePendingDir}
    process_markers ${queueDeferredDir}
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
        };
        directories = {
          downloads = downloadDir;
          incomplete = incompleteDir;
        };
        integration.scripts.beets_import = {
          on = ["DownloadDirectoryComplete"];
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
      "d ${queueDeferredDir} 2775 ${shareUser} ${shareGroup} -"
      "d ${queueFailedDir} 2775 ${shareUser} ${shareGroup} -"
    ];

    # Upstream slskd makes shared paths read-only; clear that so beets import can move files into musicDir
    systemd.services.slskd.serviceConfig = {
      SupplementaryGroups = ["share"];
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
        SupplementaryGroups = [shareGroup];
        UMask = "0002";
        ExecStart = importQueuedBeetsScript;
        ReadWritePaths = [
          queueDir
          downloadDir
          musicDir
          beetsDir
        ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

    systemd.timers.slskd-beets-import = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Persistent = true;
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
