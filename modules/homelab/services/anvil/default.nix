{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.anvil;
  downloadsRoot = config.modules.homelab.mediaShare.downloadsRoot;
  package = inputs.anvil.packages.${pkgs.system}.default;
  shareUser = "share";
  shareGroup = "share";
  shareUmask = "0002";
  profileName = "qsv-hevc-sonarr-veryslow";
  animeProfileName = "qsv-av1-sonarr-anime-veryslow";
  radarrProfileName = "qsv-hevc-radarr-slow";
  radarrAnimeProfileName = "qsv-av1-radarr-anime-slow";
  flowName = "download-av1-handoff";
  qsvFfmpegArgs = [
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
      inherit package;
      user = shareUser;
      group = shareGroup;

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
        "validate"
        "handoff"
        "cleanup"
      ];

      profiles = {
        ${profileName} = {
          metadataMode = "preserve";
          trackTitleMode = "standardize";

          video = {
            codec = "hevc";
            accelerator = "qsv";
            preset = "veryslow";
            bitDepth = 10;
            crfMin = 14;
            crfMax = 38;
            targetVmaf = 95;
            minSavingsPercent = 5;
            forceEncodeOnNoFit = true;
            ffmpegArgs = qsvFfmpegArgs;
            abAv1Args = qsvAbAv1Args;

            dolbyVision = {
              mode = "auto";
              codec = "hevc";
              accelerator = "qsv";
              preset = "veryslow";
              bitDepth = 10;
              removeHDR10Plus = false;
            };
          };

          audio = {
            languagesToKeep = [
              "orig"
              "deu"
            ];
            fallback = "keep_first";
            unknownAsOriginal = true;
          };

          subtitles = subtitleCleanup;

          validation.durationToleranceSeconds = 2;
        };

        ${animeProfileName} = {
          metadataMode = "preserve";
          trackTitleMode = "standardize";

          video = {
            codec = "av1";
            accelerator = "qsv";
            preset = "veryslow";
            bitDepth = 10;
            crfMin = 14;
            crfMax = 38;
            targetVmaf = 97;
            minSavingsPercent = 0;
            forceEncodeOnNoFit = true;
            ffmpegArgs = qsvFfmpegArgs;
            abAv1Args = qsvAbAv1Args;

            dolbyVision = {
              mode = "auto";
              codec = "hevc";
              accelerator = "qsv";
              preset = "veryslow";
              bitDepth = 10;
              removeHDR10Plus = false;
            };
          };

          audio = {
            languagesToKeep = [
              "orig"
              "deu"
            ];
            fallback = "keep_first";
            unknownAsOriginal = true;
          };

          subtitles = subtitleCleanup;

          validation.durationToleranceSeconds = 2;
        };

        ${radarrProfileName} = {
          metadataMode = "preserve";
          trackTitleMode = "standardize";

          video = {
            codec = "hevc";
            accelerator = "qsv";
            preset = "slow";
            bitDepth = 10;
            crfMin = 14;
            crfMax = 38;
            targetVmaf = 95;
            minSavingsPercent = 5;
            forceEncodeOnNoFit = true;
            ffmpegArgs = qsvFfmpegArgs;
            abAv1Args = qsvAbAv1Args;

            dolbyVision = {
              mode = "auto";
              codec = "hevc";
              accelerator = "qsv";
              preset = "slow";
              bitDepth = 10;
              removeHDR10Plus = false;
            };
          };

          audio = {
            languagesToKeep = [
              "orig"
              "deu"
            ];
            fallback = "keep_first";
            unknownAsOriginal = true;
          };

          subtitles = subtitleCleanup;

          validation.durationToleranceSeconds = 2;
        };

        ${radarrAnimeProfileName} = {
          metadataMode = "preserve";
          trackTitleMode = "standardize";

          video = {
            codec = "av1";
            accelerator = "qsv";
            preset = "slow";
            bitDepth = 10;
            crfMin = 14;
            crfMax = 38;
            targetVmaf = 97;
            minSavingsPercent = 0;
            forceEncodeOnNoFit = true;
            ffmpegArgs = qsvFfmpegArgs;
            abAv1Args = qsvAbAv1Args;

            dolbyVision = {
              mode = "auto";
              codec = "hevc";
              accelerator = "qsv";
              preset = "slow";
              bitDepth = 10;
              removeHDR10Plus = false;
            };
          };

          audio = {
            languagesToKeep = [
              "orig"
              "deu"
            ];
            fallback = "keep_first";
            unknownAsOriginal = true;
          };

          subtitles = subtitleCleanup;

          validation.durationToleranceSeconds = 2;
        };
      };

      arrs = {
        radarr = {
          type = "radarr";
          baseUrl = "http://127.0.0.1:7878/radarr";
          apiKeyFile = config.sops.secrets.anvil_radarr_api_key.path;
        };
        sonarr = {
          type = "sonarr";
          baseUrl = "http://127.0.0.1:8989/sonarr";
          apiKeyFile = config.sops.secrets.anvil_sonarr_api_key.path;
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
          "share"
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

    sops.secrets = {
      anvil_radarr_api_key = {
        owner = shareUser;
        group = shareGroup;
        mode = "0400";
      };

      anvil_sonarr_api_key = {
        owner = shareUser;
        group = shareGroup;
        mode = "0400";
      };
    };
  };
}
