{
  stdenvNoCC,
  fetchurl,
  lib,
}:
stdenvNoCC.mkDerivation rec {
  pname = "cliproxyapi";
  version = "7.2.151";
  src = fetchurl {
    url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_linux_amd64_no-plugin.tar.gz";
    sha256 = "59c8d63e1dfda732e58f075b98ff3ba23a8fcfadb760e1a351bfc7d6206cd882";
  };
  sourceRoot = ".";
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 cli-proxy-api $out/bin/cli-proxy-api
    runHook postInstall
  '';
  meta = {
    description = "Subscription proxy with OpenAI-compatible APIs";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    mainProgram = "cli-proxy-api";
  };
}
