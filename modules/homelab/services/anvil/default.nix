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
    veryslowProfile = "qsv-hevc-veryslow";
    slowProfile = "qsv-hevc-slow";
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
    mediaFiles = {
      include = [
        "*.mkv"
        "*.mp4"
      ];
      exclude = [
        "**/sample*/**"
        "**/*sample*"
      ];
      ignore_regex = [
        "(^|/)_UNPACK[^/]*(/|$)"
        "(?i)(^|/)[^/]*samples?[^/]*(/|$)"
      ];
    };
    mkProfile = preset: samples: {
      metadata = {
        mode = "preserve";
        track_titles = "standardize";
      };

      video = {
        codec = "hevc";
        accelerator = "qsv";
        inherit preset;
        bit_depth = 10;
        crf_min = 8;
        crf_max = 28;
        inherit samples;
        metric = "vmaf";
        target = 96;
        min_savings_percent = 0;
        force_encode_on_no_fit = true;
        ffmpeg_args = qsvFfmpegArgs;
        ab_av1_args = qsvAbAv1Args;
        overrides.hevc.target = 98;
      };

      audio = {
        languages_to_keep = [
          "orig"
          "deu"
        ];
        fallback = "keep_first";
        unknown_as_original = true;
      };
      subtitles = {
        languages_to_keep = [
          "orig"
          "deu"
        ];
        fallback = "keep_all";
        keep_forced = true;
        keep_sdh = true;
        keep_commentary = true;
        unknown_as_original = true;
      };
      validation.duration_tolerance_seconds = 2;
    };
    mkDownloadLibrary = {
      path,
      handoffPath,
      arr,
      profile,
      priority,
    }:
      mediaFiles
      // {
        kind = "download";
        inherit path arr profile priority;
        scan_interval = "5m";
        download = {
          handoff_path = handoffPath;
          stable_for = "5m";
          package_mode = "auto";
          handoff_mode = "move";
          preserve_relative_path = true;
          cleanup_source_media = true;
          prune_empty_dirs = true;
        };
      };
    mkMediaLibrary = {
      path,
      arr,
      profile,
    }:
      mediaFiles
      // {
        kind = "media";
        inherit path arr profile;
        scan_interval = "1h";
        media.replacement_mode = "replace";
      };
  in {
    imports = [
      inputs.anvil.nixosModules.default
    ];

    options.services.homelab.anvil.enable =
      lib.mkEnableOption "Anvil media encoding daemon";

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

        settings = {
          daemon = {
            control_socket = "/run/anvil/anvild.sock";
            scan_interval = "1h";
            worker_count = 2;
            total_threads = 12;
          };

          profiles = {
            ${veryslowProfile} = mkProfile "veryslow" 10;
            ${slowProfile} = mkProfile "slow" 14;
          };

          arrs = {
            radarr = {
              type = "radarr";
              base_url = config.services.homelab.radarr.baseUrl;
              api_key_file = config.sops.secrets.radarr_api_key.path;
            };
            sonarr = {
              type = "sonarr";
              base_url = config.services.homelab.sonarr.baseUrl;
              api_key_file = config.sops.secrets.sonarr_api_key.path;
            };
          };

          libraries = {
            movies = mkMediaLibrary {
              path = "/tank/media/movies";
              arr = "radarr";
              profile = slowProfile;
            };
            shows = mkMediaLibrary {
              path = "/tank/media/shows";
              arr = "sonarr";
              profile = veryslowProfile;
            };
            anime = mkMediaLibrary {
              path = "/tank/media/anime";
              arr = "sonarr";
              profile = veryslowProfile;
            };

            radarr-downloads = mkDownloadLibrary {
              path = "${downloadsRoot}/complete/radarr";
              handoffPath = "${downloadsRoot}/converted/radarr";
              arr = "radarr";
              profile = slowProfile;
              priority = 10;
            };
            sonarr-downloads = mkDownloadLibrary {
              path = "${downloadsRoot}/complete/sonarr";
              handoffPath = "${downloadsRoot}/converted/sonarr";
              arr = "sonarr";
              profile = veryslowProfile;
              priority = 10;
            };
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

      systemd.services.anvil.environment.LIBVA_DRIVER_NAME = "iHD";
      systemd.services.anvil.restartTriggers = [
        config.environment.etc."anvil/anvil.toml".source
      ];

      # Radarr and Sonarr use one global API key each. Other services share
      # these files.
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
