{buildNpmPackage}: {src}:
buildNpmPackage {
  pname = "agent-stuff";
  version = "1.0.0";
  inherit src;

  npmDepsHash = "sha256-V46FzcTugJ3i0OH91dwWBUheIL6xi/+z0GIttec7Xtw=";
  npmInstallFlags = ["--ignore-scripts"];
  dontNpmBuild = true;
  doCheck = false;

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --ignore-scripts

    # Pi's bundled Bun runtime rejects follow-redirects' Error subclass in
    # Error.captureStackTrace on Linux. Pass a real Error until Bun fixes its
    # Node compatibility (oven-sh/bun#15750).
    substituteInPlace node_modules/follow-redirects/index.js \
      --replace-fail \
      'Error.captureStackTrace(this, this.constructor);' \
      'Error.captureStackTrace(new Error(), this.constructor);'

    mkdir -p "$out"
    cp -r \
      LICENSE \
      LICENSES \
      NOTICE \
      README.md \
      extensions \
      node_modules \
      package.json \
      skills \
      themes \
      "$out/"

    runHook postInstall
  '';
}
