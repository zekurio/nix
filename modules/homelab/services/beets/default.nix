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

    beetsConfig = (pkgs.formats.yaml {}).generate "beets-config.yaml" {
      directory = musicDir;
      library = "${stateDir}/library.db";
      plugins = pluginNames;

      import = {
        autotag = true;
        copy = false;
        duplicate_action = "skip";
        from_scratch = true;
        log = importLog;
        move = true;
        quiet = false;
        quiet_fallback = "skip";
        resume = true;
        write = true;
      };

      paths = {
        default = "$albumartist/$album%aunique{}/$track - $title";
        singleton = "Singles/$artist/$title";
        comp = "Compilations/$album%aunique{}/$track - $title";
      };

      match.preferred = {
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

      musicbrainz.genres = true;

      fetchart = {
        auto = true;
        cautious = false;
        cover_format = "JPEG";
        enforce_ratio = true;
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
        sources = [
          "lrclib"
          "genius"
        ];
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

      # This is deliberately manual until the request frontend owns a durable
      # acquisition queue. It provides the eventual worker boundary without
      # running Beets inside slskd.service or racing incomplete downloads.
      systemd.services.beets-import = {
        description = "Import completed Soulseek downloads with Beets";
        after = [
          "local-fs.target"
          "systemd-tmpfiles-setup.service"
        ];
        requires = ["systemd-tmpfiles-setup.service"];
        unitConfig.RequiresMountsFor = "${stateDir} ${musicDir} ${importDir}";
        serviceConfig = {
          Type = "oneshot";
          User = serviceUser;
          Group = mediaShare.group;
          UMask = lib.mkForce mediaShare.umask;
          ExecStart = "${lib.getExe beetInternal} import -m -q --from-scratch ${lib.escapeShellArg importDir}";
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
    };
  };
}
