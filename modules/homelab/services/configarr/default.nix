{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.configarr;
    normalProfile = "[German] HD Bluray + WEB";
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
        package = inputs.configarr.packages.${pkgs.stdenv.hostPlatform.system}.default;
        schedule = "*-*-* 05:00:00";
        environmentFile = config.sops.templates."configarr.env".path;
        config = ''
          trashRevision: 34e6a8cc67621052a6903dcc912eb515332fb3b8
          telemetry: false

          sonarr:
            sonarr:
              base_url: ${config.services.homelab.sonarr.baseUrl}
              api_key: !env SONARR_API_KEY
              include:
                - template: dca7e5e9e99c703bcbdaaa471dd40e98 # [German] HD Bluray + WEB
                  source: TRASH
                - template: 6fe5937e1dcc2269e23b49eb46dfe6d6 # [German] Anime HD Bluray + WEB
                  source: TRASH

              custom_formats:
                - trash_ids:
                    - 505d871304820ba7106b693be6fe4a9e # HDR
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 500
                    - name: "${animeProfile}"
                      score: 500
                - trash_ids:
                    - 7c3a61a9c6cb04f52f1544be6d44a026 # DV Boost
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 1000
                    - name: "${animeProfile}"
                      score: 1000
                - trash_ids:
                    - 0c4b99df9206d2cfac3c05ab897dd62a # HDR10+ Boost
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 100
                    - name: "${animeProfile}"
                      score: 100
                - trash_ids:
                    - 9b27ab6498ec0f31a3353992e19434ca # DV (w/o HDR fallback)
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: -10000
                    - name: "${animeProfile}"
                      score: -10000
                - trash_ids:
                    - 9b64dff695c2115facf1b6ea59c9bd07 # x265 (no HDR/DV)
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: -35000
                    - name: "${animeProfile}"
                      score: -35000

          radarr:
            radarr:
              base_url: ${config.services.homelab.radarr.baseUrl}
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
                - trash_ids:
                    - 493b6d1dbec3c3364c59d7607f7e3405 # HDR
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 500
                    - name: "${animeProfile}"
                      score: 500
                    - name: "${animeUhdProfile}"
                      score: 500
                - trash_ids:
                    - b337d6812e06c200ec9a2d3cfa9d20a7 # DV Boost
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 1000
                    - name: "${animeProfile}"
                      score: 1000
                    - name: "${animeUhdProfile}"
                      score: 1000
                - trash_ids:
                    - caa37d0df9c348912df1fb1d88f9273a # HDR10+ Boost
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 100
                    - name: "${animeProfile}"
                      score: 100
                    - name: "${animeUhdProfile}"
                      score: 100
                - trash_ids:
                    - 923b6abef9b17f937fab56cfcf89e1f1 # DV (w/o HDR fallback)
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: -10000
                    - name: "${animeProfile}"
                      score: -10000
                    - name: "${animeUhdProfile}"
                      score: -10000
                - trash_ids:
                    - 839bea857ed2c0a8e084f3cbdbd65ecb # x265 (no HDR/DV)
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: -35000
                    - name: "${animeProfile}"
                      score: -35000
                    - name: "${animeUhdProfile}"
                      score: -35000

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
  };
}
