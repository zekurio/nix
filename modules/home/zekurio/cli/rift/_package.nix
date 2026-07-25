{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "rift";
  version = "0.0.10";

  src = fetchurl {
    url = "https://github.com/anomalyco/rift/releases/download/v${finalAttrs.version}/rift-v${finalAttrs.version}-aarch64-apple-darwin.tar.gz";
    hash = "sha256-92c6lb2AlXjnyq/YMrQmp9ycy57rLwWIw8APrUTBWSQ=";
  };

  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    runHook postUnpack
  '';
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 rift "$out/bin/rift"
    runHook postInstall
  '';

  meta = {
    description = "Copy-on-write alternative to Git worktrees";
    homepage = "https://github.com/anomalyco/rift";
    license = lib.licenses.mit;
    mainProgram = "rift";
    platforms = ["aarch64-darwin"];
  };
})
