{
  nixpkgs.overlays = [
    (final: prev: let
      jellyfinVersion = "12.0-rc1";
      jellyfinFfmpegVersion = "8.1.1-4";
      jellyfinSrc = final.fetchFromGitHub {
        owner = "jellyfin";
        repo = "jellyfin";
        tag = "v${jellyfinVersion}";
        hash = "sha256-/VIwHt5OW53GoEkInRcMXckpPxbHdEdd/wLwn4wZlec=";
      };
      jellyfinWebSrc = final.fetchFromGitHub {
        owner = "jellyfin";
        repo = "jellyfin-web";
        tag = "v${jellyfinVersion}";
        hash = "sha256-A5geOb3rUuc+nCMHkodBbGKWUdrA4+2oosYqZ6fSLMI=";
      };
      jellyfinWebPostPatch = ''
        substituteInPlace webpack.common.js \
          --replace-fail "git describe --always --dirty" "echo v${jellyfinVersion}"

        jq 'del(.packages["node_modules/pdfjs-dist"].optionalDependencies.canvas)' \
          package-lock.json > package-lock.json.tmp
        mv package-lock.json.tmp package-lock.json
      '';
      jellyfinBuildDotnetModule = args:
        final.buildDotnetModule (
          finalAttrs: let
            attrs =
              if final.lib.isFunction args
              then args finalAttrs
              else args;
          in
            attrs
            // {
              version = jellyfinVersion;
              src = jellyfinSrc;
              dotnet-sdk = final.dotnetCorePackages.sdk_10_0;
              dotnet-runtime = final.dotnetCorePackages.aspnetcore_10_0;
              nugetDeps = ./nuget-deps.json;
              preVersionCheck = ''
                version=12.0.0.0
              '';
              versionCheckProgramArg = "--help";
            }
        );
    in {
      jellyfin-ffmpeg =
        (final.ffmpeg_8-full.override {
          version = jellyfinFfmpegVersion;
          source = final.fetchFromGitHub {
            owner = "jellyfin";
            repo = "jellyfin-ffmpeg";
            tag = "v${jellyfinFfmpegVersion}";
            hash = "sha256-Dt4GmPJIogteQlwF+bcwzjtiPeGhzcnU38C7P+NQTtU=";
          };
        })
        .overrideAttrs (old: {
          pname = "jellyfin-ffmpeg";

          configureFlags =
            old.configureFlags
            ++ [
              "--extra-version=Jellyfin"
            ];

          postPatch = ''
            for file in $(cat debian/patches/series); do
              patch -p1 < debian/patches/$file
            done

            ${old.postPatch or ""}
          '';

          meta =
            old.meta
            // {
              changelog = "https://github.com/jellyfin/jellyfin-ffmpeg/releases/tag/v${jellyfinFfmpegVersion}";
              description = "${old.meta.description} (Jellyfin fork)";
              homepage = "https://github.com/jellyfin/jellyfin-ffmpeg";
              maintainers = with final.lib.maintainers; [justinas];
              pkgConfigModules = ["libavutil"];
            };
        });

      jellyfin-web = (prev.jellyfin-web.override {nodejs_22 = final.nodejs_24;}).overrideAttrs (finalAttrs: previousAttrs: {
        version = jellyfinVersion;

        src = jellyfinWebSrc;

        nodejs = final.nodejs_24;
        postPatch = jellyfinWebPostPatch;
        nativeBuildInputs = (previousAttrs.nativeBuildInputs or []) ++ [final.jq];
        npmDeps = final.fetchNpmDeps {
          src = jellyfinWebSrc;
          name = "jellyfin-web-${jellyfinVersion}-npm-deps";
          nativeBuildInputs = [final.jq];
          postPatch = jellyfinWebPostPatch;
          hash = "sha256-OuvnDTFOpHMXRhCLowfSOYpbSp+9h+Pq/EZPwzfMDwU=";
        };
        preBuild = ''
          rm -rf node_modules/sass-embedded*
        '';
      });

      jellyfin = prev.jellyfin.override {
        buildDotnetModule = jellyfinBuildDotnetModule;
        dotnetCorePackages =
          prev.dotnetCorePackages
          // {
            sdk_9_0 = final.dotnetCorePackages.sdk_10_0;
            aspnetcore_9_0 = final.dotnetCorePackages.aspnetcore_10_0;
          };
        jellyfin-ffmpeg = final.jellyfin-ffmpeg;
        jellyfin-web = final.jellyfin-web;
      };
    })
  ];
}
