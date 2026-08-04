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
    profileName = "qsv-hevc-sonarr-veryslow";
    animeProfileName = "qsv-av1-sonarr-anime-veryslow";
    radarrProfileName = "qsv-hevc-radarr-slow";
    radarrAnimeProfileName = "qsv-av1-radarr-anime-slow";
    flowName = "download-av1-handoff";
    qsvFfmpegArgs = [
      "-look_ahead"
      "1"
      "-extbrc"
      "1"
      "-look_ahead_depth"
      "40"
      "-adaptive_i"
      "1"
      "-adaptive_b"
      "1"
      "-b_strategy"
      "1"
      "-bf"
      "7"
    ];
    qsvAbAv1Args = [
      # ab-av1's native 10-bit XPSNR path can produce invalid scores for
      # portrait and some non-16:9 sources. Compare in 8-bit until upstream's
      # XPSNR filter handles those layouts reliably.
      "--xpsnr-pix-format"
      "yuv420p"
      "--enc"
      "look_ahead=1"
      "--enc"
      "extbrc=1"
      "--enc"
      "look_ahead_depth=40"
      "--enc"
      "adaptive_i=1"
      "--enc"
      "adaptive_b=1"
      "--enc"
      "b_strategy=1"
      "--enc"
      "bf=7"
    ];
    audioCleanup = {
      languagesToKeep = [
        "orig"
        "deu"
      ];
      fallback = "keep_first";
      unknownAsOriginal = true;
    };
    subtitleCleanup = {
      languagesToKeep = [
        "orig"
        "deu"
      ];
      fallback = "keep_all";
      keepForced = true;
      keepSdh = true;
      keepCommentary = true;
      unknownAsOriginal = true;
    };

    # Savings are a hard gate: an encode that cannot reduce the source by the
    # applicable threshold is copied instead. Normal content targets XPSNR 40;
    # anime and already-compressed HEVC sources use the stricter XPSNR 42
    # target. Normal Dolby Vision sources remain untouched.
    mkProfile = {
      codec,
      preset,
      anime ? false,
    }: {
      metadata = {
        mode = "preserve";
        trackTitles = "standardize";
      };

      video = {
        inherit codec preset;
        accelerator = "qsv";
        bitDepth = 10;
        crfMin = 14;
        crfMax = 38;
        metric = "xpsnr";
        target =
          if anime
          then 42
          else 40;
        minSavingsPercent = 1;
        forceEncodeOnNoFit = false;
        ffmpegArgs = qsvFfmpegArgs;
        abAv1Args = qsvAbAv1Args;

        overrides = {
          # Require a higher score for another lossy generation, while still
          # letting the savings gate preserve efficient HEVC releases.
          hevc = {
            target = 42;
            skipEncode = false;
          };

          dolby_vision =
            {
              codec = "hevc";
              accelerator = "qsv";
              inherit preset;
              bitDepth = 10;
            }
            // lib.optionalAttrs (!anime) {
              # Normal Dolby Vision releases must remain untouched.
              skipEncode = true;
            };
        };

        dolbyVision = {
          mode = "auto";
          removeHdr10plus = false;
        };
      };

      audio = audioCleanup;
      subtitles = subtitleCleanup;
      validation.durationToleranceSeconds = 2;
    };

    mkDownloadLibrary = {
      path,
      handoffPath,
      arr,
      profile ? profileName,
      priority,
    }: {
      kind = "download";
      inherit path arr priority;
      flow = flowName;
      inherit profile;
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
      enable = lib.mkEnableOption "Anvil AV1 encoding daemon";
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
        daemon.workerCount = 2;
        daemon.totalThreads = 8;

        flows.${flowName}.steps = [
          "probe"
          "crop-detect"
          "audio-cleanup"
          "subtitle-cleanup"
          "stage"
          "crf-search"
          "encode"
          "dovi-fix"
          "track-stats"
          "validate"
          "handoff"
          "cleanup"
        ];

        profiles = {
          ${profileName} = mkProfile {
            codec = "hevc";
            preset = "veryslow";
          };

          ${animeProfileName} = mkProfile {
            codec = "av1";
            preset = "veryslow";
            anime = true;
          };

          ${radarrProfileName} = mkProfile {
            codec = "hevc";
            preset = "slow";
          };

          ${radarrAnimeProfileName} = mkProfile {
            codec = "av1";
            preset = "slow";
            anime = true;
          };
        };

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
            profile = radarrProfileName;
            priority = 10;
          };

          radarr-anime-downloads = mkDownloadLibrary {
            path = "${downloadsRoot}/complete/radarr-anime";
            handoffPath = "${downloadsRoot}/converted/radarr-anime";
            arr = "radarr";
            profile = radarrAnimeProfileName;
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
            profile = animeProfileName;
            priority = 20;
          };
        };

        service.extraServiceConfig = {
          SupplementaryGroups = [
            shareGroup
            "render"
            "video"
          ];
          UMask = shareUmask;
          WorkingDirectory = "/var/lib/anvil/tmp";
        };
      };

      systemd.services.anvil.environment = {
        LIBVA_DRIVER_NAME = "iHD";
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
