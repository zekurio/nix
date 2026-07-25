{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.beets;
    mediaShare = config.modules.homelab.mediaShare;
    downloadsRoot = mediaShare.downloadsRoot;
    musicDir = mediaShare.musicDir;
    importDir = "${downloadsRoot}/complete/slskd";
    stateDir = "/var/lib/beets";
    slskdDownloadsApi = "http://127.0.0.1:5030/slskd/api/v0/transfers/downloads";
    beetsConfig = (pkgs.formats.yaml {}).generate "beets-config.yaml" {
      directory = musicDir;
      library = "${stateDir}/library.db";
      plugins = "fetchart embedart lastgenre chroma duplicates";
      import = {
        copy = false;
        move = true;
        write = true;
        autotag = true;
        resume = true;
        timid = false;
        quiet_fallback = "asis";
        duplicate_action = "skip";
      };
      paths = {
        default = "$albumartist/$album%aunique{}/$track $title";
        singleton = "Singles/$artist/$title";
        comp = "Compilations/$album%aunique{}/$track $title";
      };
      match = {
        preferred = {
          media = ["CD" "Digital Media" "Vinyl"];
          countries = ["XW" "US" "GB" "JP" "XE"];
        };
      };
      fetchart = {
        auto = true;
        cautious = false;
        high_resolution = true;
        enforce_ratio = true;
        sources = [
          "coverart"
          "itunes"
          "albumart"
          "cover_art_url"
          "filesystem"
        ];
        cover_names = [
          "cover"
          "Cover"
          "front"
          "Front"
          "folder"
          "Folder"
          "album"
          "art"
        ];
      };
      embedart = {
        auto = true;
        ifempty = false;
        remove_art_file = false;
      };
    };
    beetMusic = pkgs.writeShellApplication {
      name = "beet-music";
      runtimeInputs = with pkgs; [
        beets
        chromaprint
        ffmpeg
      ];
      text = ''
        umask ${mediaShare.umask}
        export BEETSDIR=${stateDir}
        export HOME=${stateDir}
        exec beet -c ${beetsConfig} "$@"
      '';
    };
    beetImportSlskd = pkgs.writeShellApplication {
      name = "beet-import-slskd";
      runtimeInputs = with pkgs; [
        beets
        chromaprint
        coreutils
        curl
        ffmpeg
        findutils
        gnugrep
        jq
        util-linux
      ];
      text = ''
        umask ${mediaShare.umask}
        export BEETSDIR=${stateDir}
        export HOME=${stateDir}

        log() {
          printf 'beet-import-slskd: %s\n' "$*" >&2
        }

        if [ -z "''${SLSKD_SCRIPT_DATA:-}" ]; then
          exit 0
        fi

        payload="$(mktemp)"
        transfers="$(mktemp)"
        cleanup() {
          rm -f "$payload" "$transfers"
        }
        trap cleanup EXIT

        printf '%s' "$SLSKD_SCRIPT_DATA" > "$payload"

        target="$(jq -r '.localDirectoryName // empty' <<< "$SLSKD_SCRIPT_DATA")"
        if [ -z "$target" ]; then
          exit 0
        fi

        target="$(realpath -m "$target")"
        import_root="$(realpath -m ${lib.escapeShellArg importDir})"
        case "$target" in
          "$import_root"/*) ;;
          *) exit 1 ;;
        esac

        if ! find "$target" -mindepth 1 -type f -print -quit | grep -q .; then
          exit 0
        fi

        username="$(jq -r '.username // empty' "$payload")"
        remote_directory="$(jq -r '.directory // .remoteDirectory // .remoteDirectoryName // .directoryName // empty' "$payload")"
        target_name="$(basename "$target")"

        if ! curl -fsS --max-time 10 ${lib.escapeShellArg slskdDownloadsApi} > "$transfers"; then
          log "skipping $target: could not query slskd transfer state"
          exit 0
        fi

        matched="$(
          jq --arg username "$username" --arg remote "$remote_directory" --arg target_name "$target_name" '
            [
              .[]
              | select($username == "" or .username == $username)
              | .directories[]
              | select(
                  ($remote != "" and .directory == $remote)
                  or ((.directory | split("\\") | last) == $target_name)
                )
            ]
          ' "$transfers"
        )"

        match_count="$(jq 'length' <<< "$matched")"
        if [ "$match_count" -eq 0 ]; then
          log "skipping $target: no matching slskd transfer directory"
          exit 0
        fi

        expected_audio_count="$(
          jq '
            def audio: .filename | test("(?i)\\.(flac|mp3|m4a|ogg|opus|wav|aif|aiff|aac)$");
            [ .[] | .files | map(select(audio)) | sort_by(.filename) | group_by(.filename)[] ] | length
          ' <<< "$matched"
        )"
        if [ "$expected_audio_count" -eq 0 ]; then
          log "skipping $target: slskd transfer has no audio files"
          exit 0
        fi

        bad_audio_files="$(
          jq -r '
            def audio: .filename | test("(?i)\\.(flac|mp3|m4a|ogg|opus|wav|aif|aiff|aac)$");
            def success:
              .state == "Completed, Succeeded"
              and ((.bytesRemaining // 0) == 0)
              and ((.percentComplete // 0) == 100);
            .[]
            | .files
            | map(select(audio))
            | sort_by(.filename)
            | group_by(.filename)[]
            | select(any(.[]; success) | not)
            | .[0].filename
          ' <<< "$matched"
        )"

        if [ -n "$bad_audio_files" ]; then
          log "skipping $target: slskd still has incomplete or failed audio files"
          while IFS= read -r bad_file; do
            [ -z "$bad_file" ] || log "  $bad_file"
          done <<< "$bad_audio_files"
          exit 0
        fi

        local_audio_count="$(
          find "$target" -type f \
            \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aif' -o -iname '*.aiff' -o -iname '*.aac' \) \
            -print | wc -l
        )"
        if [ "$local_audio_count" -lt "$expected_audio_count" ]; then
          log "skipping $target: only $local_audio_count of $expected_audio_count expected audio files are present locally"
          exit 0
        fi

        exec flock ${stateDir}/slskd-import.lock beet -c ${beetsConfig} import -m -q "$target"
      '';
    };
  in {
    options.services.homelab.beets = {
      enable = lib.mkEnableOption "beets music library cleanup tooling";
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        beetMusic
        beetImportSlskd
      ];

      systemd.tmpfiles.rules = [
        "d ${stateDir} 2775 ${mediaShare.user} ${mediaShare.group} -"
        "z ${stateDir} 2775 ${mediaShare.user} ${mediaShare.group} -"
      ];

      system.activationScripts.beets-state-dir-permissions.text = ''
        chown -R ${mediaShare.user}:${mediaShare.group} ${stateDir}
        chmod 2775 ${stateDir}
        find ${stateDir} -type f -exec chmod g+rw {} +
      '';

      services.slskd.settings = lib.mkIf config.services.homelab.slskd.enable {
        integration.scripts."beets-import" = {
          on = [
            "DownloadDirectoryComplete"
          ];
          run = {
            executable = "${lib.getExe pkgs.bash}";
            command = "-c ${lib.getExe beetImportSlskd}";
          };
        };
      };

      systemd.services.slskd = lib.mkIf config.services.homelab.slskd.enable {
        # The beets hook runs inside slskd.service, so it inherits slskd's
        # systemd sandbox and needs explicit write access to import/tag files.
        serviceConfig = {
          ReadOnlyPaths = lib.mkForce [];
          ReadWritePaths = [
            stateDir
            musicDir
            importDir
          ];
        };
      };
    };
  };
}
