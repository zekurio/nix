{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  icu,
  openssl,
  zlib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "lidarr-nightly";
  version = "3.1.6.5078";

  # Plugin support moved from the old plugins channel to develop/nightly.
  # nixpkgs' 3.1.0 predates that merge; use the pinned upstream .NET 8 build.
  src = fetchurl {
    url = "https://github.com/Lidarr/Lidarr/releases/download/v${finalAttrs.version}/Lidarr.develop.${finalAttrs.version}.linux-core-x64.tar.gz";
    hash = "sha256-HYFPI3bKbFxP6R/M2uOksR+xA06zRyC+Sd9wi8+MK4E=";
  };

  nativeBuildInputs = [autoPatchelfHook makeWrapper];
  buildInputs = [stdenv.cc.cc.lib zlib];
  # The optional .NET tracing provider targets an older LTTng ABI. Normal
  # execution does not load it, and Nix manages application updates.
  postUnpack = ''
    rm -f Lidarr/libcoreclrtraceptprovider.so
    rm -rf Lidarr/Lidarr.Update
  '';
  dontConfigure = true;
  dontBuild = true;
  # Stripping the bundled ReadyToRun assemblies corrupts their .NET headers.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/lidarr" "$out/bin"
    cp -a . "$out/lib/lidarr/"
    # .NET loads ICU and OpenSSL with dlopen rather than ELF dependencies.
    makeWrapper "$out/lib/lidarr/Lidarr" "$out/bin/Lidarr" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [icu openssl]}
    runHook postInstall
  '';

  meta = {
    description = "Lidarr nightly with plugin support";
    homepage = "https://lidarr.audio";
    license = lib.licenses.gpl3Only;
    mainProgram = "Lidarr";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
