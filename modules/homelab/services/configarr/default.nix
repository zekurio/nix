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
    normalUhdProfile = "[German] UHD+HD Bluray + WEB";
    animeProfile = "[German] Anime HD Bluray + WEB";
    animeUhdProfile = "[German] Anime UHD+HD Bluray + WEB";
    remuxScore = 5000;
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
        package = inputs.configarr.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
          pnpmDeps = old.pnpmDeps.overrideAttrs {
            outputHash = "sha256-auz4JyfHJAOF+baLfV391HgBTua4AJFfX4CtTPh+0Sw=";
          };
        });
        schedule = "*-*-* 05:00:00";
        environmentFile = config.sops.templates."configarr.env".path;
        config = ''
          trashRevision: 34e6a8cc67621052a6903dcc912eb515332fb3b8
          # Last recyclarr/config-templates commit with the legacy includes/
          # layout configarr loads; v8 removed them on master and crashed every
          # run (raydak-labs/configarr#504). Upstream v1.30.2 pins this same SHA
          # by default, but its Nix package still builds v1.30.1, so pin here.
          recyclarrRevision: 4ae377bb704fc7fd69a544ad04e91357e0b09f62
          telemetry: false

          # TRaSH has release-group tiers for remuxes, but no generic Radarr
          # format for the remux quality modifier. Keep the qualities merged
          # so their language/group scores remain authoritative, then
          # add enough of a bonus to prefer a remux at the same resolution,
          # all else being equal.
          # The UHD profiles' 9000-point resolution boost still wins over this
          # bonus, so it alone cannot make a 1080p remux displace a 2160p encode.
          customFormatDefinitions:
            - trash_id: radarr-remux
              trash_scores:
                default: ${toString remuxScore}
              trash_description: Prefer Radarr remuxes within a resolution
              # Configarr matches existing Radarr formats by name; keep this
              # name so the already-synced format receives the new scores.
              name: Anime Remux
              includeCustomFormatWhenRenaming: false
              specifications:
                - name: Remux
                  implementation: QualityModifierSpecification
                  negate: false
                  required: true
                  fields:
                    value: 5

          sonarr:
            sonarr:
              base_url: ${config.services.homelab.sonarr.baseUrl}
              api_key: !env SONARR_API_KEY
              # Configarr resolves TRaSH naming presets only at instance level.
              media_naming:
                series: default
                season: default
                episodes:
                  rename: true
                  standard: default
                  daily: default
                  anime: default
              media_naming_api:
                replaceIllegalCharacters: true
                multiEpisodeStyle: 5 # Prefixed Range, as recommended by TRaSH.
              include:
                - template: dca7e5e9e99c703bcbdaaa471dd40e98 # [German] HD Bluray + WEB
                  source: TRASH
                - template: 6fe5937e1dcc2269e23b49eb46dfe6d6 # [German] Anime HD Bluray + WEB
                  source: TRASH

              cloneQualityProfiles:
                - from: "${normalProfile}"
                  to: "${normalUhdProfile}"
                - from: "${animeProfile}"
                  to: "${animeUhdProfile}"

              custom_formats:
                - trash_ids:
                    - b493cd40d8a3bbf2839127a706bdb673 # German 2160p Booster
                  assign_scores_to:
                    - name: "${normalUhdProfile}"
                      score: 9000
                    - name: "${animeUhdProfile}"
                      score: 9000
                - trash_ids:
                    - 1bef6c151fa35093015b0bfef18279e5 # 2160p
                  assign_scores_to:
                    - name: "${normalUhdProfile}"
                      score: 100
                    - name: "${animeUhdProfile}"
                      score: 100
                # Use TRaSH's recommended HDR scores on every profile.
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
                # Of TRaSH's two mutually exclusive x265 blockers, only
                # "x265 (HD)" is scored: penalize HEVC at HD resolutions for
                # live action, where x264 is preferred. Anime stays neutral on
                # both: fansub and BD encode groups ship HEVC 10-bit as their
                # primary format, so a penalty below the profile's
                # min_format_score of 0 would reject most of what is actually
                # released. The explicit 0 for "x265 (no HDR/DV)" is needed
                # because the German templates assign it -35000 in both the
                # german and german-anime score sets.
                - trash_ids:
                    - 47435ece6b99a0b477caf360e79ba0bb # x265 (HD)
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: -35000
                    - name: "${animeProfile}"
                      score: 0
                - trash_ids:
                    - 9b64dff695c2115facf1b6ea59c9bd07 # x265 (no HDR/DV)
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 0
                    - name: "${animeProfile}"
                      score: 0

              # Anvil scores with VMAF. Keep 720p out so it need not upscale.
              quality_profiles:
                - name: "${normalProfile}"
                  qualities:
                    - name: Merged QPs
                      qualities:
                        - Bluray-1080p
                        - WEBRip-1080p
                        - WEBDL-1080p
                - name: "${animeProfile}"
                  qualities:
                    - name: Merged QPs
                      qualities:
                        - WEBDL-1080p
                        - WEBRip-1080p
                        - Bluray-1080p
                - name: "${normalUhdProfile}"
                  qualities:
                    - name: Merged QPs
                      qualities:
                        - Bluray-2160p
                        - WEBRip-2160p
                        - WEBDL-2160p
                        - Bluray-1080p
                        - WEBRip-1080p
                        - WEBDL-1080p
                - name: "${animeUhdProfile}"
                  qualities:
                    - name: Merged QPs
                      qualities:
                        - WEBDL-2160p
                        - WEBRip-2160p
                        - Bluray-2160p
                        - WEBDL-1080p
                        - WEBRip-1080p
                        - Bluray-1080p

          radarr:
            radarr:
              base_url: ${config.services.homelab.radarr.baseUrl}
              api_key: !env RADARR_API_KEY
              media_naming:
                folder: default
                movie:
                  rename: true
                  standard: standard
              media_naming_api:
                replaceIllegalCharacters: true
              include:
                - template: 2b90e905c99490edc7c7a5787443748b # [German] HD Bluray + WEB
                  source: TRASH
                - template: bf3cc2e99ad9a804a9b0d0e538e1fbba # [German] Anime HD Bluray + WEB
                  source: TRASH

              cloneQualityProfiles:
                - from: "${normalProfile}"
                  to: "${normalUhdProfile}"
                - from: "${animeProfile}"
                  to: "${animeUhdProfile}"

              custom_formats:
                - trash_ids:
                    - radarr-remux # Anime Remux
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: ${toString remuxScore}
                    - name: "${normalUhdProfile}"
                      score: ${toString remuxScore}
                    - name: "${animeProfile}"
                      score: ${toString remuxScore}
                    - name: "${animeUhdProfile}"
                      score: ${toString remuxScore}
                - trash_ids:
                    - cc7b1e64e2513a6a271090cdfafaeb55 # German 2160p Booster
                  assign_scores_to:
                    - name: "${normalUhdProfile}"
                      score: 9000
                    - name: "${animeUhdProfile}"
                      score: 9000
                - trash_ids:
                    - fb392fb0d61a010ae38e49ceaa24a1ef # 2160p
                  assign_scores_to:
                    - name: "${normalUhdProfile}"
                      score: 100
                    - name: "${animeUhdProfile}"
                      score: 100
                # Use TRaSH's recommended HDR scores on every profile.
                - trash_ids:
                    - 493b6d1dbec3c3364c59d7607f7e3405 # HDR
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 500
                    - name: "${normalUhdProfile}"
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
                    - name: "${normalUhdProfile}"
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
                    - name: "${normalUhdProfile}"
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
                    - name: "${normalUhdProfile}"
                      score: -10000
                    - name: "${animeProfile}"
                      score: -10000
                    - name: "${animeUhdProfile}"
                      score: -10000
                # Only "x265 (HD)" is penalized on the non-anime profiles;
                # "x265 (no HDR/DV)" is explicitly neutral because the German
                # templates otherwise assign it -35000 everywhere. See the
                # Sonarr block above for the anime rationale.
                - trash_ids:
                    - dc98083864ea246d05a42df0d05f81cc # x265 (HD)
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: -35000
                    - name: "${normalUhdProfile}"
                      score: -35000
                    - name: "${animeProfile}"
                      score: 0
                    - name: "${animeUhdProfile}"
                      score: 0
                - trash_ids:
                    - 839bea857ed2c0a8e084f3cbdbd65ecb # x265 (no HDR/DV)
                  assign_scores_to:
                    - name: "${normalProfile}"
                      score: 0
                    - name: "${normalUhdProfile}"
                      score: 0
                    - name: "${animeProfile}"
                      score: 0
                    - name: "${animeUhdProfile}"
                      score: 0

              quality_profiles:
                - name: "${normalProfile}"
                  qualities:
                    - name: Merged QPs
                      qualities:
                        - Remux-1080p
                        - Bluray-1080p
                        - WEBRip-1080p
                        - WEBDL-1080p
                - name: "${normalUhdProfile}"
                  qualities:
                    - name: Merged QPs
                      qualities:
                        - Remux-2160p
                        - Bluray-2160p
                        - WEBDL-2160p
                        - WEBRip-2160p
                        - Remux-1080p
                        - Bluray-1080p
                        - WEBRip-1080p
                        - WEBDL-1080p
                - name: "${animeProfile}"
                  qualities:
                    - name: Merged QPs
                      qualities:
                        - Remux-1080p
                        - Bluray-1080p
                        - WEBRip-1080p
                        - WEBDL-1080p
                - name: "${animeUhdProfile}"
                  qualities:
                    - name: Merged QPs
                      qualities:
                        - Remux-2160p
                        - Bluray-2160p
                        - WEBDL-2160p
                        - WEBRip-2160p
                        - Remux-1080p
                        - Bluray-1080p
                        - WEBRip-1080p
                        - WEBDL-1080p
        '';
      };

      sops.templates."configarr.env" = {
        content = ''
          SONARR_API_KEY=${config.sops.placeholder.sonarr_api_key}
          RADARR_API_KEY=${config.sops.placeholder.radarr_api_key}
          STOP_ON_ERROR=true
          TZ=${config.time.timeZone}
        '';
        inherit (config.services.configarr) group;
        owner = config.services.configarr.user;
        mode = "0400";
      };

      sops.secrets = {
        radarr_api_key = {};
        sonarr_api_key = {};
      };

      systemd.services.configarr = {
        after = ["radarr.service" "sonarr.service"];
        wants = [
          "radarr.service"
          "sonarr.service"
        ];
      };
    };
  };
}
