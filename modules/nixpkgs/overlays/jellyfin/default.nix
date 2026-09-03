let
  overlay = final: previous: let
    jellyfinVersion = "12.0-rc7";
    jellyfinFfmpegVersion = "8.1.2-3";

    jellyfinSrc = final.fetchFromGitHub {
      owner = "jellyfin";
      repo = "jellyfin";
      tag = "v${jellyfinVersion}";
      hash = "sha256-HSFBJyoAP+/GIPuVhLJIUoUEAYteTqUhJmp0RuT16QM=";
    };

    jellyfinWebSrc = final.fetchFromGitHub {
      owner = "jellyfin";
      repo = "jellyfin-web";
      tag = "v${jellyfinVersion}";
      hash = "sha256-O8VRaTnXKBuHPYZv9w0GPwgCqPa1Ej6wd/Lg3TacJ78=";
    };

    jellyfinWebPostPatch = ''
      substituteInPlace webpack.common.js \
        --replace-fail "git describe --always --dirty" "echo v${jellyfinVersion}"

      jq 'del(.packages["node_modules/pdfjs-dist"].optionalDependencies.canvas)' \
        package-lock.json > package-lock.json.tmp
      mv package-lock.json.tmp package-lock.json
    '';

    # Jellyfin 12 targets .NET 10, while the stable nixpkgs expression still
    # builds 10.11 with .NET 9. Replacing buildDotnetModule lets the package's
    # existing expression keep supplying its other build arguments.
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
          hash = "sha256-86qI2Oer+p6kaj3Wo5KIWHlCbsxT1qwe65aLyr1/GZA=";
        };
        buildFfplay = false;
        buildFfprobe = true;
        withSamba = false;
        withSdl2 = false;
      }).overrideAttrs (old: {
        pname = "jellyfin-ffmpeg";

        configureFlags =
          old.configureFlags
          ++ ["--extra-version=Jellyfin"];

        postPatch = ''
          for file in $(cat debian/patches/series); do
            patch -p1 < debian/patches/$file
          done

          ${old.postPatch or ""}
        '';

        meta = {
          inherit (old.meta) license mainProgram;
          changelog = "https://github.com/jellyfin/jellyfin-ffmpeg/releases/tag/v${jellyfinFfmpegVersion}";
          description = "${old.meta.description} (Jellyfin fork)";
          homepage = "https://github.com/jellyfin/jellyfin-ffmpeg";
          maintainers = with final.lib.maintainers; [justinas];
          pkgConfigModules = ["libavutil"];
        };
      });

    jellyfin-web = (previous.jellyfin-web.override {nodejs_22 = final.nodejs_24;}).overrideAttrs (_finalAttrs: previousAttrs: {
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
        hash = "sha256-Pz2qI616aFg61ldkZIRJHGk/3T5FsN/vEXtPGszm4Cw=";
      };
      preBuild = ''
        rm -rf node_modules/sass-embedded*
      '';
    });

    jellyfin = previous.jellyfin.override {
      buildDotnetModule = jellyfinBuildDotnetModule;
      jellyfin-ffmpeg = final.jellyfin-ffmpeg;
      jellyfin-web = final.jellyfin-web;
    };
  };
in {
  flake.modules.nixos.base.nixpkgs.overlays = [overlay];
}
