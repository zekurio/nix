{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.configarr;
  animeProfile = "[German] Anime HD Bluray + WEB";
  animeUhdProfile = "[German] Anime UHD+HD Bluray + WEB";
in {
  imports = [
    inputs.configarr.nixosModules.default
  ];

  options.services.homelab.configarr = {
    enable = lib.mkEnableOption "Configarr synchronization for Sonarr and Radarr";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.homelab.radarr.enable;
        message = "services.homelab.configarr requires services.homelab.radarr.";
      }
      {
        assertion = config.services.homelab.sonarr.enable;
        message = "services.homelab.configarr requires services.homelab.sonarr.";
      }
    ];

    services.configarr = {
      enable = true;
      package = inputs.configarr.packages.${pkgs.system}.default;
      schedule = "*-*-* 05:00:00";
      environmentFile = config.sops.templates."configarr.env".path;
      config = ''
        trashRevision: 34e6a8cc67621052a6903dcc912eb515332fb3b8
        telemetry: false

        sonarr:
          sonarr:
            base_url: http://127.0.0.1:8989/sonarr
            api_key: !env SONARR_API_KEY
            include:
              - template: dca7e5e9e99c703bcbdaaa471dd40e98 # [German] HD Bluray + WEB
                source: TRASH
              - template: 6fe5937e1dcc2269e23b49eb46dfe6d6 # [German] Anime HD Bluray + WEB
                source: TRASH

        radarr:
          radarr:
            base_url: http://127.0.0.1:7878/radarr
            api_key: !env RADARR_API_KEY
            include:
              - template: 2b90e905c99490edc7c7a5787443748b # [German] HD Bluray + WEB
                source: TRASH
              - template: bf3cc2e99ad9a804a9b0d0e538e1fbba # [German] Anime HD Bluray + WEB
                source: TRASH

            cloneQualityProfiles:
              - from: "${animeProfile}"
                to: "${animeUhdProfile}"

            custom_formats:
              - trash_ids:
                  - cc7b1e64e2513a6a271090cdfafaeb55 # German 2160p Booster
                assign_scores_to:
                  - name: "${animeUhdProfile}"
                    score: 9000
              - trash_ids:
                  - fb392fb0d61a010ae38e49ceaa24a1ef # 2160p
                assign_scores_to:
                  - name: "${animeUhdProfile}"
                    score: 100

            quality_profiles:
              - name: "${animeUhdProfile}"
                qualities:
                  - name: Merged QPs
                    qualities:
                      - Bluray-2160p
                      - WEBDL-2160p
                      - WEBRip-2160p
                      - Bluray-1080p
                      - WEBRip-1080p
                      - WEBDL-1080p
                      - Bluray-720p
                      - WEBDL-720p
                      - WEBRip-720p
      '';
    };

    sops.templates."configarr.env" = {
      content = ''
        SONARR_API_KEY=${config.sops.placeholder.anvil_sonarr_api_key}
        RADARR_API_KEY=${config.sops.placeholder.anvil_radarr_api_key}
        STOP_ON_ERROR=true
        TZ=${config.time.timeZone}
      '';
      inherit (config.services.configarr) group;
      owner = config.services.configarr.user;
      mode = "0400";
    };

    sops.secrets = {
      anvil_radarr_api_key = {};
      anvil_sonarr_api_key = {};
    };

    systemd.services.configarr = {
      after = [
        "radarr.service"
        "sonarr.service"
      ];
      wants = [
        "radarr.service"
        "sonarr.service"
      ];
    };
  };
}
