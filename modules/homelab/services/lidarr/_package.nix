{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  icu,
  openssl,
  zlib,
}:
# nixpkgs' 3.1.0 predates plugins. Tubifarry 2.1.1 requires Lidarr >= 3.1.3.
stdenvNoCC.mkDerivation rec {
  pname = "lidarr";
  version = "3.1.5.5066";
  src = fetchurl {
    url = "https://github.com/Lidarr/Lidarr/releases/download/v${version}/Lidarr.develop.${version}.linux-core-x64.tar.gz";
    hash = "sha256-+XFgopDHh7WkJ4izjS4mJLndWnfC4eXcLPjId46Egfc=";
  };
  nativeBuildInputs = [autoPatchelfHook makeWrapper];
  # Stripping ReadyToRun assemblies corrupts the bundled .NET runtime.
  dontStrip = true;
  buildInputs = [stdenv.cc.cc.lib zlib];
  # .NET's optional tracing provider targets an older LTTng ABI.
  autoPatchelfIgnoreMissingDeps = ["liblttng-ust.so.0"];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/lidarr" "$out/bin"
    cp -a . "$out/lib/lidarr/"
    makeWrapper "$out/lib/lidarr/Lidarr" "$out/bin/Lidarr" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [icu openssl]}
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    export HOME="$TMPDIR"
    "$out/bin/Lidarr" '-?' -data="$TMPDIR/lidarr-check" > help.txt
    grep -q 'Usage: Lidarr' help.txt
  '';
  meta = {
    description = "Lidarr with plugin support";
    homepage = "https://lidarr.audio";
    license = lib.licenses.gpl3Only;
    platforms = ["x86_64-linux"];
    mainProgram = "Lidarr";
  };
}
