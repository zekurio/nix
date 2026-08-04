{buildNpmPackage}: {src}:
buildNpmPackage {
  pname = "agent-stuff";
  version = "1.0.0";
  inherit src;

  npmDepsHash = "sha256-V46FzcTugJ3i0OH91dwWBUheIL6xi/+z0GIttec7Xtw=";
  npmInstallFlags = ["--ignore-scripts"];
  dontNpmBuild = true;
  doCheck = false;

  # Keep the shared package focused on the providers used by this profile. The
  # upstream source is also consumed by other agents, so strip provider-specific
  # fallbacks and routing here instead of changing the shared input.
  postPatch = ''
    sed -i '/pi-anthropic-auth/d' package.json
    rm -rf extensions/pi-anthropic-auth
    sed -i '/const HAIKU_MODEL_ID/d' extensions/answer.ts
    sed -i 's/then haiku, then the/then the/' extensions/answer.ts
    sed -i 's/(haiku, gpt-5.4-mini)/(gpt-5.4-mini)/' extensions/async-agents.ts
    sed -i '/^[[:space:]]*const haikuModel = modelRegistry.find/,/^[[:space:]]*return haikuModel;/d' extensions/answer.ts
    sed -i '/async function selectExtractionModel/,/^}$/ {
      /^}$/i\
     return currentModel;
    }' extensions/answer.ts
    sed -i 's/^ return currentModel;/    return currentModel;/' extensions/answer.ts
    sed -i 's|, "anthropic/claude-fable-5:high"||' extensions/async-agents.ts
    sed -i '/^[[:space:]]*anthropic: {/,/^[[:space:]]*},/d' extensions/priority-routing.ts
    sed -i 's/ && basename !== "claude.md"//' extensions/git-flow.ts
    sed -i '/Anthropic authentication/d' README.md
    sed -i '/^The Anthropic authentication extension is derived from/,/^License is included at extensions\/pi-anthropic-auth\/LICENSE\.$/d' NOTICE
  '';

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
