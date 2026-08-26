{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: let
  release = builtins.getAttr stdenvNoCC.hostPlatform.system {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-92c6lb2AlXjnyq/YMrQmp9ycy57rLwWIw8APrUTBWSQ=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-wcH9D65jvgBphDWqbeXssk+89iksJijk0OABgJ9ruZ0=";
    };
  };
in {
  pname = "rift";
  version = "0.0.10";

  src = fetchurl {
    url = "https://github.com/anomalyco/rift/releases/download/v${finalAttrs.version}/rift-v${finalAttrs.version}-${release.target}.tar.gz";
    inherit (release) hash;
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
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
})
