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
    soulseekImportDir = "${mediaShare.downloadsRoot}/complete/slskd";
    copypartyImportDir = "${mediaShare.downloadsRoot}/complete/copyparty";
    importDirs = [
      soulseekImportDir
      copypartyImportDir
    ];
    importDirsShell = lib.concatStringsSep " " (map lib.escapeShellArg importDirs);
    lockFile = "${stateDir}/library.lock";
    importLog = "${stateDir}/import.log";
    scanStamp = "${stateDir}/import.scan";
    cleanupStamp = "${stateDir}/metadata-cleanup-v1";
    libraryRefreshDir = "${stateDir}/library-refresh-mbpseudo-square-art-lyrics-v2";
    libraryRefreshComplete = "${libraryRefreshDir}/complete";
    libraryLayoutStamp = "${stateDir}/music-layout-disc-directories-v1";
    pluginNames = [
      "chroma"
      "duplicates"
      "embedart"
      "fetchart"
      "inline"
      "lastgenre"
      "lyrics"
      "mbpseudo"
      "mbsync"
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

    normalizeMusicArtwork = pkgs.writeShellApplication {
      name = "normalize-music-artwork";
      text = ''
        exec ${lib.getExe (pkgs.python3.withPackages (pythonPackages: [
          beetsPackage
          pythonPackages.pillow
        ]))} ${./normalize-music-artwork.py} \
          --config ${lib.escapeShellArg beetsConfig} \
          --max-deviation 0.01
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

      # Keep multi-disc releases together as one album, but put each medium in
      # its own directory. Continuous release-wide numbering remains unchanged.
      item_fields.multidisc = "1 if disctotal > 1 else 0";
      paths = {
        default = "$albumartist/$album%aunique{}/%if{$multidisc,Disc $disc/}$track - $title";
        singleton = "Singles/$artist/$title";
        comp = "Compilations/$album%aunique{}/%if{$multidisc,Disc $disc/}$track - $title";
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

        # Prefer western digital releases when several official releases are
        # otherwise equivalent. mbpseudo still handles translated tracklists
        # linked to an exact non-Latin release ID.
        preferred = {
          media = [
            "Digital Media"
            "CD"
            "Vinyl"
          ];
          countries = [
            "XW"
            "US"
            "GB"
            "DE"
            "JP"
            "XE"
          ];
        };
      };

      # Use Latin-script MusicBrainz pseudo-releases (translated tracklists)
      # while retaining release details from the linked official release.
      mbpseudo = {
        genres = true;
        scripts = ["Latn"];
      };

      fetchart = {
        auto = true;
        # Only accept explicitly named local images as the fallback. Loose
        # release-group and text searches regularly selected another edition
        # or an unrelated release.
        cautious = true;
        cover_format = "JPEG";
        # Permit minor scan misalignment while rejecting booklets, banners,
        # and back covers that clients would otherwise display uncropped.
        enforce_ratio = "1%";
        maxwidth = 1400;
        sources = [
          {coverart = "release";}
          "itunes"
          {coverart = "releasegroup";}
          "filesystem"
        ];
        store_source = true;
      };

      embedart = {
        auto = true;
        # Source files often contain unrelated downloader artwork. Remove it
        # before fetchart/embedart install the validated album cover.
        clearart_on_import = true;
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
        # Replace downloader-provided lyrics instead of preserving malformed
        # app-specific tags, and write plain lyrics for Feishin.
        force = true;
        sources = ["lrclib"];
        synced = false;
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

    beetsLibraryRefresh = pkgs.writeShellApplication {
      name = "beets-library-refresh";
      runtimeInputs = [
        beetsPackage
        pkgs.coreutils
        pkgs.util-linux
      ];
      text = ''
        umask ${mediaShare.umask}
        export BEETSDIR=${lib.escapeShellArg stateDir}
        export HOME=${lib.escapeShellArg stateDir}
        export XDG_CACHE_HOME=${lib.escapeShellArg "${stateDir}/.cache"}

        refresh_dir=${lib.escapeShellArg libraryRefreshDir}
        mkdir -p "$refresh_dir"

        # Hold one lock across every phase so an import cannot observe a
        # partially refreshed library. Calling beetInternal here would try to
        # acquire the same lock recursively and deadlock.
        exec 9>${lib.escapeShellArg lockFile}
        flock -x 9

        run_phase() {
          phase="$1"
          shift
          if [ -e "$refresh_dir/$phase" ]; then
            echo "Skipping completed Beets library refresh phase: $phase"
            return
          fi

          ${lib.getExe beetsPackage} -c ${lib.escapeShellArg beetsConfig} "$@"
          touch "$refresh_dir/$phase"
        }

        # Apply the new naming policy before looking up artwork and lyrics.
        # Phase stamps allow a failed or interrupted refresh to resume without
        # repeating successful external API requests.
        run_phase mbsync mbsync -m

        if [ ! -e "$refresh_dir/normalize-artwork" ]; then
          ${lib.getExe normalizeMusicArtwork}
          touch "$refresh_dir/normalize-artwork"
        fi

        run_phase fetchart fetchart -f
        # Remove every downloader embed, then repopulate tracks only from the
        # validated sidecar selected by normalize-artwork/fetchart.
        run_phase clearart clearart -y
        run_phase embedart embedart -y
        run_phase lyrics lyrics -f
        touch ${lib.escapeShellArg libraryRefreshComplete}
      '';
    };

    beetsLibraryLayout = pkgs.writeShellApplication {
      name = "beets-library-layout";
      runtimeInputs = [
        beetsPackage
        pkgs.coreutils
        pkgs.util-linux
      ];
      text = ''
        umask ${mediaShare.umask}
        export BEETSDIR=${lib.escapeShellArg stateDir}
        export HOME=${lib.escapeShellArg stateDir}
        export XDG_CACHE_HOME=${lib.escapeShellArg "${stateDir}/.cache"}

        exec 9>${lib.escapeShellArg lockFile}
        flock -x 9

        ${lib.getExe beetsPackage} -c ${lib.escapeShellArg beetsConfig} \
          move "disctotal:2.."
        touch ${lib.escapeShellArg libraryLayoutStamp}
      '';
    };

    beetsImportWorker = pkgs.writeShellApplication {
      name = "beets-import-worker";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
      ];
      text = ''
        import_dirs=(${importDirsShell})

        # Downloaders keep active files elsewhere or under a .PARTIAL name.
        # Remove only settled, empty directories from completed trees.
        for import_dir in "''${import_dirs[@]}"; do
          find "$import_dir" -mindepth 1 -depth -type d -empty -mmin +2 -delete
        done

        if ! find "''${import_dirs[@]}" -mindepth 1 -type f ! -name '*.PARTIAL' -print -quit | grep -q .; then
          echo "No completed music files to import."
          exit 0
        fi

        scan_boundary=$(mktemp)
        trap 'rm -f "$scan_boundary"' EXIT

        # Copyparty atomically renames completed uploads, but leaves resumable
        # .PARTIAL files in place. Never hand a set to Beets while one remains.
        if find ${lib.escapeShellArg copypartyImportDir} -type f -name '*.PARTIAL' -print -quit | grep -q .; then
          echo "Deferring Beets import while a Copyparty upload is incomplete."
          exit 0
        fi

        if find "''${import_dirs[@]}" -type f -mmin -2 -print -quit | grep -q .; then
          echo "Deferring Beets import until the completed trees have settled."
          exit 0
        fi

        # Beets' incremental history keys only on the directory path, so a
        # repaired or resumed download at the same path would otherwise never
        # be reconsidered. Select changed top-level sets ourselves and disable
        # Beets' path-only incremental check for this bounded import.
        candidates=()
        shopt -s dotglob nullglob
        for import_dir in "''${import_dirs[@]}"; do
          for path in "$import_dir"/*; do
            if [ ! -e ${lib.escapeShellArg cleanupStamp} ] \
              || [ ! -e ${lib.escapeShellArg scanStamp} ] \
              || [ "$path" -nt ${lib.escapeShellArg scanStamp} ] \
              || find "$path" -type f -newer ${lib.escapeShellArg scanStamp} -print -quit | grep -q .; then
              candidates+=("$path")
            fi
          done
        done

        if [ "''${#candidates[@]}" -eq 0 ]; then
          echo "No new or changed completed music paths to import."
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

      # Existing files predate the Latin-name, square-artwork, and plain-lyrics
      # policy. Refresh every library item once; future imports already apply
      # the policy automatically. Bump the versioned directory for another
      # intentional full-library migration.
      systemd.services.beets-library-refresh = {
        description = "Refresh the Beets library metadata, artwork, and lyrics";
        after = [
          "local-fs.target"
          "network-online.target"
          "systemd-tmpfiles-setup.service"
        ];
        before = ["beets-import.service"];
        wants = ["network-online.target"];
        requires = ["systemd-tmpfiles-setup.service"];
        restartIfChanged = false;
        unitConfig = {
          ConditionPathExists = "!${libraryRefreshComplete}";
          RequiresMountsFor = "${stateDir} ${musicDir}";
        };
        serviceConfig = {
          Type = "oneshot";
          User = serviceUser;
          Group = mediaShare.group;
          UMask = lib.mkForce mediaShare.umask;
          ExecStart = lib.getExe beetsLibraryRefresh;
          TimeoutStartSec = "infinity";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            stateDir
            musicDir
          ];
        };
      };

      # Delay the potentially long migration so switching configurations does
      # not wait for every MusicBrainz and LRCLIB request to finish.
      systemd.timers.beets-library-refresh = {
        description = "Run the versioned Beets library refresh";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnActiveSec = "5m";
          AccuracySec = "30s";
          Unit = "beets-library-refresh.service";
        };
      };

      # Move existing multi-disc albums once; future imports use the same path
      # template immediately.
      systemd.services.beets-library-layout = {
        description = "Organize multi-disc Beets albums into disc directories";
        after = [
          "local-fs.target"
          "systemd-tmpfiles-setup.service"
        ];
        before = ["beets-import.service"];
        requires = ["systemd-tmpfiles-setup.service"];
        restartIfChanged = false;
        unitConfig = {
          ConditionPathExists = "!${libraryLayoutStamp}";
          RequiresMountsFor = "${stateDir} ${musicDir}";
        };
        serviceConfig = {
          Type = "oneshot";
          User = serviceUser;
          Group = mediaShare.group;
          UMask = lib.mkForce mediaShare.umask;
          ExecStart = lib.getExe beetsLibraryLayout;
          TimeoutStartSec = "infinity";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            stateDir
            musicDir
          ];
        };
      };

      systemd.services.beets-import = {
        description = "Import completed music downloads with Beets";
        after = [
          "beets-library-layout.service"
          "local-fs.target"
          "systemd-tmpfiles-setup.service"
        ];
        requires = [
          "beets-library-layout.service"
          "systemd-tmpfiles-setup.service"
        ];
        unitConfig.RequiresMountsFor = "${stateDir} ${musicDir} ${lib.concatStringsSep " " importDirs}";
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
          ReadWritePaths =
            [
              stateDir
              musicDir
            ]
            ++ importDirs;
        };
      };

      # A timer avoids repeated path triggers while slskd finishes a set. The
      # worker also checks that the completed tree has been quiet for two
      # minutes.
      systemd.timers.beets-import = {
        description = "Periodically import completed music downloads";
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
