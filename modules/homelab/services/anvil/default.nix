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
  profileName = "qsv-av1";
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

      daemon = {
        tempDir = "/var/tmp/anvil";
        storePath = "/var/lib/anvil/anvil.db";
      };

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

      profiles.${profileName} = {
        video = {
          codec = "av1_qsv";
          preset = "medium";
          pixelFormat = "p010le";
          targetVmaf = 95;
          minSavingsPercent = 20;
          ffmpegArgs = qsvFfmpegArgs;
          abAv1Args = qsvAbAv1Args;

          dolbyVision = {
            mode = "auto";
            codec = "hevc_qsv";
            preset = "medium";
            pixelFormat = "p010le";
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

        sonarr-downloads = mkDownloadLibrary {
          path = "/var/lib/downloads/complete/sonarr";
          handoffPath = "/var/lib/downloads/converted/sonarr";
          arr = "sonarr";
          priority = 10;
        };
      };

      service.extraServiceConfig = {
        SupplementaryGroups = [
          "render"
          "video"
        ];
        UMask = shareUmask;
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/tmp/anvil 2775 ${shareUser} ${shareGroup} -"
    ];

    systemd.services.anvil.environment = {
      LIBVA_DRIVER_NAME = "iHD";
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
