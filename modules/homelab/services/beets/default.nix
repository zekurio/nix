{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.beets;
    mediaShare = config.modules.homelab.mediaShare;
    serviceUser = "beets";
    stateDir = "/var/lib/beets";
    musicDir = mediaShare.musicDir;
    importDir = "${mediaShare.downloadsRoot}/complete/slskd";
    lockFile = "${stateDir}/library.lock";
    importLog = "${stateDir}/import.log";
    scanStamp = "${stateDir}/import.scan";
    cleanupStamp = "${stateDir}/metadata-cleanup-v1";
    slskdApi = "http://127.0.0.1:5030/slskd/api/v0/transfers/downloads";

    pluginNames = [
      "chroma"
      "duplicates"
      "embedart"
      "fetchart"
      "lastgenre"
      "lyrics"
      "musicbrainz"
      "scrub"
      "zero"
    ];

    beetsPackage = pkgs.python3Packages.beets.override {
      disableAllPlugins = true;
      pluginOverrides = lib.genAttrs pluginNames (_: {enable = true;});
    };

    cleanMusicMetadata = pkgs.writeShellApplication {
      name = "clean-music-metadata";
      text = ''
        exec ${lib.getExe (pkgs.python3.withPackages (pythonPackages: [pythonPackages.mutagen]))} \
          ${./clean-music-metadata.py} "$@"
      '';
    };

    beetsConfig = (pkgs.formats.yaml {}).generate "beets-config.yaml" {
      directory = musicDir;
      library = "${stateDir}/library.db";
      plugins = pluginNames;

      import = {
        autotag = true;
        copy = false;
        duplicate_action = "skip";
        from_scratch = true;
        incremental = true;
        # Record rejected paths for ad-hoc incremental imports. The worker
        # separately detects changed sets because Beets only remembers the
        # directory name, not its contents.
        incremental_skip_later = false;
        languages = ["en"];
        log = importLog;
        move = true;
        quiet = false;
        quiet_fallback = "skip";
        resume = false;
        write = true;
      };

      paths = {
        default = "$albumartist/$album%aunique{}/$track - $title";
        singleton = "Singles/$artist/$title";
        comp = "Compilations/$album%aunique{}/$track - $title";
      };

      match = {
        # This is Beets' internal metadata-provider identity, not an audio tag.
        # Penalizing its absence dominates otherwise exact MusicBrainz-ID and
        # track matches when more than one metadata-capable plugin is loaded.
        distance_weights.data_source = 0.0;

        # Soulseek tags commonly differ by transliteration, punctuation, or a
        # single alternate track title even when their MusicBrainz IDs match.
        # Accept that moderate distance unattended; Beets' default max_rec
        # still prevents missing or unmatched tracks from becoming strong.
        strong_rec_thresh = 0.35;
      };

      musicbrainz.genres = true;

      fetchart = {
        auto = true;
        cautious = false;
        cover_format = "JPEG";
        # Cover Art Archive scans are often a few pixels off-square. Beets'
        # strict ratio check rejected otherwise valid release artwork.
        enforce_ratio = false;
        maxwidth = 1400;
        sources = [
          {coverart = "release";}
          {coverart = "releasegroup";}
          "itunes"
          "filesystem"
        ];
      };

      embedart = {
        auto = true;
        ifempty = false;
        maxwidth = 1400;
        remove_art_file = false;
      };

      lastgenre = {
        auto = true;
        canonical = true;
        count = 3;
        fallback = "";
        source = "album";
      };

      lyrics = {
        auto = true;
        fallback = "";
        force = false;
        sources = ["lrclib"];
        synced = true;
      };

      # Scrub first removes every tag that Beets does not manage. Zero then
      # clears cruft that maps to real Beets fields and would otherwise be
      # written back, such as ripper comments and encoder signatures.
      scrub.auto = true;
      zero = {
        auto = true;
        fields = [
          "comments"
          "encoder"
          "grouping"
        ];
        update_database = true;
      };
    };

    beetInternal = pkgs.writeShellApplication {
      name = "beet-music-internal";
      runtimeInputs = [
        beetsPackage
        pkgs.util-linux
      ];
      text = ''
        umask ${mediaShare.umask}
        export BEETSDIR=${lib.escapeShellArg stateDir}
        export HOME=${lib.escapeShellArg stateDir}
        export XDG_CACHE_HOME=${lib.escapeShellArg "${stateDir}/.cache"}
        exec flock -x ${lib.escapeShellArg lockFile} \
          ${lib.getExe beetsPackage} -c ${lib.escapeShellArg beetsConfig} "$@"
      '';
    };

    beetMusic = pkgs.writeShellApplication {
      name = "beet-music";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        if [ "$(id -un)" != ${lib.escapeShellArg serviceUser} ]; then
          exec /run/wrappers/bin/sudo -u ${lib.escapeShellArg serviceUser} -- \
            ${lib.getExe beetInternal} "$@"
        fi
        exec ${lib.getExe beetInternal} "$@"
      '';
    };

    beetsImportWorker = pkgs.writeShellApplication {
      name = "beets-import-worker";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.findutils
        pkgs.gnugrep
        pkgs.jq
      ];
      text = ''
        if ! find ${lib.escapeShellArg importDir} -mindepth 1 -type f -print -quit | grep -q .; then
          echo "No completed Soulseek files to import."
          exit 0
        fi

        transfers=$(mktemp)
        scan_boundary=$(mktemp)
        trap 'rm -f "$transfers" "$scan_boundary"' EXIT
        if ! curl \
          --connect-timeout 5 \
          --max-time 15 \
          --fail \
          --silent \
          --show-error \
          ${lib.escapeShellArg slskdApi} > "$transfers"; then
          echo "Deferring Beets import because the slskd API is unavailable."
          exit 0
        fi

        if jq --exit-status '
          [.. | objects | .state? // empty | select(startswith("Completed") | not)]
          | length > 0
        ' "$transfers" >/dev/null; then
          echo "Deferring Beets import while Soulseek downloads are active."
          exit 0
        fi

        if find ${lib.escapeShellArg importDir} -type f -mmin -2 -print -quit | grep -q .; then
          echo "Deferring Beets import until the completed tree has settled."
          exit 0
        fi

        # Beets' incremental history keys only on the directory path, so a
        # repaired or resumed download at the same path would otherwise never
        # be reconsidered. Select changed top-level sets ourselves and disable
        # Beets' path-only incremental check for this bounded import.
        candidates=()
        shopt -s dotglob nullglob
        for path in ${lib.escapeShellArg importDir}/*; do
          if [ ! -e ${lib.escapeShellArg cleanupStamp} ] \
            || [ ! -e ${lib.escapeShellArg scanStamp} ] \
            || [ "$path" -nt ${lib.escapeShellArg scanStamp} ] \
            || find "$path" -type f -newer ${lib.escapeShellArg scanStamp} -print -quit | grep -q .; then
            candidates+=("$path")
          fi
        done

        if [ "''${#candidates[@]}" -eq 0 ]; then
          echo "No new or changed completed Soulseek paths to import."
          exit 0
        fi

        # Strip downloader advertising and source URLs before Beets reads the
        # files. Fail closed so unclean metadata cannot reach the library when
        # a file is malformed or Mutagen cannot safely rewrite it.
        ${lib.getExe cleanMusicMetadata} "''${candidates[@]}"

        # The versioned stamp makes the first deployment clean every completed
        # path, including sets older than the incremental import watermark.
        # Bump the version when expanding the cleanup migration in the future.
        touch ${lib.escapeShellArg cleanupStamp}

        if ${lib.getExe beetInternal} import -I -m -q --from-scratch "''${candidates[@]}"; then
          # Preserve the scan's start time so a download that appears while
          # Beets is running remains newer and is picked up on the next pass.
          touch --reference="$scan_boundary" ${lib.escapeShellArg scanStamp}
        else
          status=$?
          exit "$status"
        fi
      '';
    };
  in {
    options.services.homelab.beets = {
      enable = lib.mkEnableOption "Beets music metadata and import tooling";
    };

    config = lib.mkIf cfg.enable {
      users.users.${serviceUser} = {
        isSystemUser = true;
        group = mediaShare.group;
        home = stateDir;
        description = "Beets music library manager";
      };

      environment.systemPackages = [beetMusic];

      systemd.tmpfiles.rules = [
        "d ${stateDir} 2775 ${serviceUser} ${mediaShare.group} -"
        "d ${stateDir}/.cache 2775 ${serviceUser} ${mediaShare.group} -"
        "f ${lockFile} 0664 ${serviceUser} ${mediaShare.group} -"
        "f ${importLog} 0664 ${serviceUser} ${mediaShare.group} -"
      ];

      # Earlier versions ran Beets as the shared media account. Normalize the
      # existing database and caches so the dedicated user can take ownership
      # without relying on whatever modes SQLite happened to create.
      system.activationScripts.beets-state-dir-permissions.text = ''
        if [ -d ${lib.escapeShellArg stateDir} ]; then
          chown -R ${lib.escapeShellArg serviceUser}:${lib.escapeShellArg mediaShare.group} ${lib.escapeShellArg stateDir}
          find ${lib.escapeShellArg stateDir} -type d -exec chmod 2775 {} +
          find ${lib.escapeShellArg stateDir} -type f -exec chmod 0664 {} +
        fi
      '';

      systemd.services.beets-import = {
        description = "Import completed Soulseek downloads with Beets";
        after = [
          "local-fs.target"
          "slskd.service"
          "systemd-tmpfiles-setup.service"
        ];
        wants = ["slskd.service"];
        requires = ["systemd-tmpfiles-setup.service"];
        unitConfig.RequiresMountsFor = "${stateDir} ${musicDir} ${importDir}";
        serviceConfig = {
          Type = "oneshot";
          User = serviceUser;
          Group = mediaShare.group;
          UMask = lib.mkForce mediaShare.umask;
          ExecStart = lib.getExe beetsImportWorker;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            stateDir
            musicDir
            importDir
          ];
        };
      };

      # Path activation gives normal downloads a prompt handoff. The timer
      # recovers changes below an already-existing directory and any event
      # missed while the host was down. The worker independently verifies the
      # slskd queue and a quiet filesystem before invoking Beets.
      systemd.paths.beets-import = {
        description = "Watch for completed Soulseek downloads";
        wantedBy = ["multi-user.target"];
        pathConfig = {
          PathChanged = importDir;
          Unit = "beets-import.service";
        };
      };

      systemd.timers.beets-import = {
        description = "Periodically import completed Soulseek downloads";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitInactiveSec = "5m";
          AccuracySec = "30s";
          Unit = "beets-import.service";
        };
      };
    };
  };
}
