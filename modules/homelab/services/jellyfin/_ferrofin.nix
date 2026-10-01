{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ferrofin";
  version = "1.3.1";

  src = fetchurl {
    url = "https://github.com/mangoleaf/ferrofin/releases/download/v${finalAttrs.version}/ferrofin-v${finalAttrs.version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-tqRKQnVdMnUodYjuE/nmDJQHyR9wRoJKNMpgjU1t9q4=";
  };

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ferrofin-server "$out/bin/ferrofin-server"
    runHook postInstall
  '';

  meta = {
    description = "Rust media server with the Jellyfin API and TVDB metadata";
    homepage = "https://github.com/mangoleaf/ferrofin";
    license = lib.licenses.gpl3Only;
    mainProgram = "ferrofin-server";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
