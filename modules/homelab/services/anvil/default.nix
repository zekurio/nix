{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.anvil;
    downloadsRoot = config.modules.homelab.mediaShare.downloadsRoot;
    daemonPackage = inputs.anvil.packages.${pkgs.stdenv.hostPlatform.system}.anvild;
    controlPackage = inputs.anvil.packages.${pkgs.stdenv.hostPlatform.system}.anvilctl;
    shareUser = config.modules.homelab.mediaShare.user;
    shareGroup = config.modules.homelab.mediaShare.group;
    shareUmask = config.modules.homelab.mediaShare.umask;
    profileName = "audio-cleanup";
    flowName = "download-audio-cleanup-handoff";
    audioCleanup = {
      languagesToKeep = [
        "orig"
        "deu"
      ];
      fallback = "keep_first";
      unknownAsOriginal = true;
    };
    profileConfig = {
      metadata = {
        mode = "preserve";
        trackTitles = "standardize";
      };

      video.skipEncode = true;

      audio = audioCleanup;
      validation.durationToleranceSeconds = 2;
    };

    mkDownloadLibrary = {
      path,
      handoffPath,
      arr,
      priority,
    }: {
      kind = "download";
      inherit path arr priority;
      flow = flowName;
      profile = profileName;
      include = [
        "*.mkv"
        "*.mp4"
      ];
      exclude = [
        "**/sample*/**"
        "**/*sample*"
      ];
      ignoreRegex = [
        "(^|/)_UNPACK[^/]*(/|$)"
        "(?i)(^|/)[^/]*samples?[^/]*(/|$)"
      ];
      download = {
        inherit handoffPath;
        stableFor = "5m";
        packageMode = "auto";
        handoffMode = "move";
        preserveRelativePath = true;
        cleanupSourceMedia = true;
        pruneEmptyDirs = true;
      };
    };
  in {
    imports = [
      inputs.anvil.nixosModules.default
    ];

    options.services.homelab.anvil = {
      enable = lib.mkEnableOption "Anvil media cleanup daemon";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.modules.homelab.mediaShare.enable;
          message = "services.homelab.anvil requires modules.homelab.mediaShare.enable for the shared media user and download directories.";
        }
      ];

      services.anvil = {
        enable = true;
        package = daemonPackage;
        user = shareUser;
        group = shareGroup;
        controlClient = {
          install = true;
          package = controlPackage;
        };

        daemon.scanInterval = "5m";
        daemon.workerCount = 1;

        flows.${flowName}.steps = [
          "probe"
          "audio-cleanup"
          "stage"
          # The encode block performs the remux; skipEncode above guarantees
          # that the video stream is copied rather than transcoded.
          "encode"
          "validate"
          "handoff"
          "cleanup"
        ];

        profiles.${profileName} = profileConfig;

        arrs = {
          radarr = {
            type = "radarr";
            baseUrl = config.services.homelab.radarr.baseUrl;
            apiKeyFile = config.sops.secrets.radarr_api_key.path;
          };
          sonarr = {
            type = "sonarr";
            baseUrl = config.services.homelab.sonarr.baseUrl;
            apiKeyFile = config.sops.secrets.sonarr_api_key.path;
          };
        };

        libraries = {
          radarr-downloads = mkDownloadLibrary {
            path = "${downloadsRoot}/complete/radarr";
            handoffPath = "${downloadsRoot}/converted/radarr";
            arr = "radarr";
            priority = 10;
          };

          radarr-anime-downloads = mkDownloadLibrary {
            path = "${downloadsRoot}/complete/radarr-anime";
            handoffPath = "${downloadsRoot}/converted/radarr-anime";
            arr = "radarr";
            priority = 20;
          };

          sonarr-downloads = mkDownloadLibrary {
            path = "${downloadsRoot}/complete/sonarr";
            handoffPath = "${downloadsRoot}/converted/sonarr";
            arr = "sonarr";
            priority = 10;
          };

          sonarr-anime-downloads = mkDownloadLibrary {
            path = "${downloadsRoot}/complete/sonarr-anime";
            handoffPath = "${downloadsRoot}/converted/sonarr-anime";
            arr = "sonarr";
            priority = 20;
          };
        };

        service.extraServiceConfig = {
          UMask = shareUmask;
          WorkingDirectory = "/var/lib/anvil/tmp";
        };
      };

      systemd.services.anvil.environment = {
        TEMP = "/var/lib/anvil/tmp";
        TMP = "/var/lib/anvil/tmp";
        TMPDIR = "/var/lib/anvil/tmp";
      };
      systemd.services.anvil.restartTriggers = [
        config.environment.etc."anvil/anvil.toml".source
      ];

      # Radarr/Sonarr issue one global API key each, so these are shared with
      # calthing and configarr rather than scoped per consumer.
      sops.secrets = {
        radarr_api_key = {
          owner = shareUser;
          group = shareGroup;
          mode = "0400";
        };

        sonarr_api_key = {
          owner = shareUser;
          group = shareGroup;
          mode = "0400";
        };
      };
    };
  };
}
