{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.anvil;
  package = inputs.anvil.packages.${pkgs.system}.default;
  shareUser = "share";
  shareGroup = "share";
  shareUmask = "0002";
  profileName = "qsv-hevc";
  animeProfileName = "qsv-av1-anime";
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
      daemon.workerCount = 3;

      flows.${flowName}.steps = [
        "probe"
        "crop-detect"
        "audio-cleanup"
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
            codec = "hevc_qsv";
            preset = "veryslow";
            pixelFormat = "yuv420p10le";
            targetVmaf = 95;
            minSavingsPercent = 5;
            ffmpegArgs = qsvFfmpegArgs;
            abAv1Args = qsvAbAv1Args;

            dolbyVision = {
              mode = "auto";
              codec = "hevc_qsv";
              preset = "veryslow";
              pixelFormat = "yuv420p10le";
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

          subtitles = {
            mode = "preserve";
            fallback = "keep_all";
            keepForced = true;
            keepExternal = true;
          };

          validation.durationToleranceSeconds = 2;
        };

        ${animeProfileName} = {
          metadataMode = "preserve";
          trackTitleMode = "standardize";

          video = {
            codec = "av1_qsv";
            preset = "veryslow";
            pixelFormat = "yuv420p10le";
            targetVmaf = 97;
            minSavingsPercent = 0;
            ffmpegArgs = qsvFfmpegArgs;
            abAv1Args = qsvAbAv1Args;
          };

          audio = {
            languagesToKeep = [
              "orig"
              "jpn"
              "deu"
            ];
            fallback = "keep_first";
            unknownAsOriginal = true;
          };

          subtitles = {
            mode = "preserve";
            fallback = "keep_all";
            keepForced = true;
            keepExternal = true;
          };

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
          path = "/var/lib/downloads/complete/radarr";
          handoffPath = "/var/lib/downloads/converted/radarr";
          arr = "radarr";
          priority = 10;
        };

        radarr-anime-downloads = mkDownloadLibrary {
          path = "/var/lib/downloads/complete/radarr-anime";
          handoffPath = "/var/lib/downloads/converted/radarr-anime";
          arr = "radarr";
          profile = animeProfileName;
          priority = 20;
        };

        sonarr-downloads = mkDownloadLibrary {
          path = "/var/lib/downloads/complete/sonarr";
          handoffPath = "/var/lib/downloads/converted/sonarr";
          arr = "sonarr";
          priority = 10;
        };

        sonarr-anime-downloads = mkDownloadLibrary {
          path = "/var/lib/downloads/complete/sonarr-anime";
          handoffPath = "/var/lib/downloads/converted/sonarr-anime";
          arr = "sonarr";
          profile = animeProfileName;
          priority = 20;
        };
      };

      service.extraServiceConfig = {
        SupplementaryGroups = [
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
