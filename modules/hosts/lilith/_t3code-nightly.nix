{
  appimageTools,
  fetchurl,
  lib,
}:
appimageTools.wrapType2 rec {
  pname = "t3code-nightly";
  version = "0.0.34-nightly.20260814.1093";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-svUJRN9Nsg+BzKNuqC4/HHslINK0NvdGvixyVK/Hnvo=";
  };

  extraInstallCommands = let
    contents = appimageTools.extract {inherit pname version src;};
  in ''
    install -Dm444 ${contents}/t3code.desktop \
      "$out/share/applications/t3-code-nightly.desktop"
    substituteInPlace "$out/share/applications/t3-code-nightly.desktop" \
      --replace-fail "Exec=AppRun" "Exec=t3code-nightly" \
      --replace-fail "Name=T3 Code (Nightly)" "Name=T3 Code Nightly"

    install -Dm444 ${contents}/t3code.png \
      "$out/share/icons/hicolor/512x512/apps/t3-code-nightly.png"
    substituteInPlace "$out/share/applications/t3-code-nightly.desktop" \
      --replace-fail "Icon=t3code" "Icon=t3-code-nightly"
  '';

  meta = {
    description = "Nightly build of the minimal GUI for coding agents";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3code-nightly";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
