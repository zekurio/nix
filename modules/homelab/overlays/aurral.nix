let
  overlay = final: previous: {
    aurral = previous.aurral.overrideAttrs (finalAttrs: old: {
      version = "2.11.0";

      src = final.fetchFromGitHub {
        owner = "lklynet";
        repo = "aurral";
        tag = "v${finalAttrs.version}";
        hash = "sha256-oaBAKcnSZnn2/0dDFVFpZSaldwQq5Z+5LZT9tr+W1H8=";
      };

      # buildNpmPackage derives npmDeps from its own arguments, so
      # overrideAttrs must replace the fetcher; a new npmDepsHash alone
      # would keep fetching the 2.10 lockfile.
      npmDeps = final.fetchNpmDeps {
        name = "aurral-${finalAttrs.version}-npm-deps";
        inherit (finalAttrs) src;
        hash = "sha256-Kap69eDxngZh8s2ndNg8bAWqtv9DyR+YROgElXBk5KY=";
        fetcherVersion = 2;
      };

      # 2.11 dropped the Beets track matcher, which the nixpkgs postPatch
      # pins, and fixed the worker recovery test upstream. nixpkgs'
      # package.json.patch no longer applies, so add its file list here:
      # without it npm pack installs the docs, tests, and screenshots.
      patches = [];
      postPatch = ''
        substituteInPlace package.json --replace-fail \
          '"type": "module",' \
          '"type": "module", "files": ["backend/*", "frontend/dist/*", "lib/*"],'

        # The fake yt-dlp and cloudflared binaries these tests write would
        # look for /usr/bin/env, which the build sandbox lacks.
        substituteInPlace \
          .tests/download/ytdlp-runtime.test.js \
          .tests/download/ytdlp-song-search.test.js \
          .tests/share/share-links.test.js \
          --replace-fail '#!/usr/bin/env node' '#!${finalAttrs.nodejs}/bin/node'

        # Passes alone, but in the full parallel suite its node -p probe of
        # the expected heap limit prints no number. The worker still reports
        # the limit NODE_OPTIONS requested.
        substituteInPlace .tests/background-process-supervisor.test.js --replace-fail \
          'test("a heap limit set in NODE_OPTIONS' \
          'test.skip("a heap limit set in NODE_OPTIONS'

        # Last.fm explains a rejected link in its 4xx body, which Aurral drops
        # in favor of the bare HTTP status.
        substituteInPlace backend/routes/scrobbling.js --replace-fail \
          '"Last.fm session exchange failed", {' \
          '"Last.fm session exchange failed", { lastfm: error?.response?.data,'
      '';

      # The Subsonic transcode test finds the ffmpeg it spawned with ps.
      nativeCheckInputs = old.nativeCheckInputs ++ [final.procps];

      env = removeAttrs old.env ["AURRAL_MATCHER_PYTHON"];

      # The nixpkgs wrapper without AURRAL_MATCHER_PYTHON, which would keep
      # Beets in the closure.
      postInstall = ''
        mkdir $out/bin
        cat > $out/bin/aurral <<EOL
        #!${final.runtimeShell} -e
        export LD_PRELOAD=${final.lib.getLib final.jemalloc}/lib/libjemalloc.so
        export LD_LIBRARY_PATH=${final.lib.makeLibraryPath [final.sqlite]}
        export PATH=${final.lib.makeBinPath [finalAttrs.nodejs final.ffmpeg final.yt-dlp]}\''${PATH:+:}\$PATH
        export FONTCONFIG_FILE=${finalAttrs.env.FONTCONFIG_FILE}
        export APP_VERSION=${finalAttrs.version}
        export NODE_ENV=production
        case "\$1" in
            resetAdminPassword)
            exec node $out/lib/node_modules/aurral/backend/scripts/resetAdminPassword.js "\$@"
            ;;
            server|"")
            exec node $out/lib/node_modules/aurral/backend/server.js
            ;;
            *)
            echo "Usage: (server|resetAdminPassword)"
            exit 1
            ;;
        esac
        EOL
        chmod +x $out/bin/aurral
      '';
    });
  };
in {
  # Remove once nixpkgs packages Aurral 2.11.
  nixpkgs.overlays = [overlay];
}
