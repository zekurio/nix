{buildNpmPackage}:
buildNpmPackage {
  pname = "pi-firecrawl-search";
  version = "1.0.0";

  src = ./extensions/firecrawl-search;
  npmDepsHash = "sha256-RzUtStmydMGqF/avpEon6q7H+Y+4RvRaac4iZs6pXKk=";
  npmInstallFlags = ["--ignore-scripts"];
  dontNpmBuild = true;

  # index.ts imports @earendil-works/pi-{ai,coding-agent}, which Pi injects at
  # runtime rather than installing. They cannot be added as devDependencies to
  # run `npm test` here either: pi-coding-agent sets hasShrinkwrap, so npm omits
  # integrity hashes for its nested deps and prefetch-npm-deps then refuses the
  # lockfile. Run `npm test` under Pi's own toolchain instead.
  doCheck = false;

  installPhase = ''
    runHook preInstall

    # Pi executes TypeScript extensions directly; only the source and production
    # dependencies are needed at runtime.
    npm prune --omit=dev --ignore-scripts

    # Pi's bundled Bun runtime rejects follow-redirects' Error subclass in
    # Error.captureStackTrace on Linux. Pass a real Error until Bun fixes its
    # Node compatibility (oven-sh/bun#15750).
    substituteInPlace node_modules/follow-redirects/index.js \
      --replace-fail \
      'Error.captureStackTrace(this, this.constructor);' \
      'Error.captureStackTrace(new Error(), this.constructor);'

    mkdir -p $out
    cp index.ts prompt.ts package.json $out/
    cp -r node_modules $out/

    runHook postInstall
  '';
}
