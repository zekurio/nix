{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "starship";
  version = "1.26.0";

  src = fetchurl {
    url = "https://github.com/starship/starship/releases/download/v${finalAttrs.version}/starship-aarch64-apple-darwin.tar.gz";
    hash = "sha256-xAsnsR9YBBHgaPL6bBvngwo4fAvEepTR038ysFTFNh0=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 starship $out/bin/starship

    runHook postInstall
  '';

  meta = {
    description = "Minimal, blazing fast, and extremely customizable prompt for any shell";
    homepage = "https://starship.rs";
    license = lib.licenses.isc;
    mainProgram = "starship";
    platforms = ["aarch64-darwin"];
  };
})
