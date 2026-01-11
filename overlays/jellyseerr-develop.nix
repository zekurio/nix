inputs: final: prev: let
  nodejs = prev.nodejs_22;
  pnpm = prev.pnpm_10.override {inherit nodejs;};
in {
  jellyseerr = prev.stdenv.mkDerivation (finalAttrs: {
    pname = "jellyseerr";
    version = "develop";

    src = prev.fetchFromGitHub {
      owner = "seerr-team";
      repo = "seerr";
      rev = "develop";
      hash = "sha256-qdYWfNZVl+sefvj9fpsG61RGoCc35Tlk2s5W+xiDlgc=";
    };

    pnpmDeps = prev.fetchPnpmDeps {
      inherit (finalAttrs) pname src;
      inherit pnpm;
      fetcherVersion = 1;
      hash = "sha256-ZhkE/snz6DMxKIekclgCY3jDs492lUlQspvoflR2dFQ=";
    };

    buildInputs = [prev.sqlite];

    nativeBuildInputs = with prev; [
      python3
      python3Packages.distutils
      nodejs
      pnpm
      makeWrapper
      (pnpmConfigHook.override {inherit pnpm;})
    ];

    preBuild = ''
      export npm_config_nodedir=${nodejs}
      pushd node_modules
      pnpm rebuild bcrypt sqlite3
      popd
    '';

    buildPhase = ''
      runHook preBuild

      pnpm build
      CI=true pnpm prune --prod --ignore-scripts
      rm -rf .next/cache

      # Clean up broken symlinks left behind by `pnpm prune`
      # https://github.com/pnpm/pnpm/issues/3645
      find node_modules -xtype l -delete

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share
      cp -r -t $out/share .next node_modules dist public package.json seerr-api.yml
      runHook postInstall
    '';

    postInstall = ''
      mkdir -p $out/bin
      makeWrapper '${nodejs}/bin/node' "$out/bin/jellyseerr" \
        --add-flags "$out/share/dist/index.js" \
        --chdir "$out/share" \
        --set NODE_ENV production
    '';

    meta = with prev.lib; {
      description = "Fork of overseerr for jellyfin support (develop branch)";
      homepage = "https://github.com/seerr-team/seerr";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.linux;
      mainProgram = "jellyseerr";
    };
  });
}
