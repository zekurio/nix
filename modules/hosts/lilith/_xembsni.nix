{
  fetchFromGitHub,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "xembsni";
  # Upstream has no tags yet; Cargo.toml still says 0.0.1.
  version = "0.0.1-unstable-2026-11-11";

  src = fetchFromGitHub {
    owner = "jmylchreest";
    repo = "xembsni";
    rev = "1501eb54a145ba36abd8c35eadc90370e69e4de4";
    hash = "sha256-X0NI2v9fz5leFDRaUoClAevT2wDvFzgg5MFnI6e33BE=";
  };

  cargoHash = "sha256-Gal2PriDqWY/PKGku/2Yas0IKnHw/J4/5IJuhTihUr4=";

  # The workspace also builds the mktray and winetray test clients.
  cargoBuildFlags = ["--package" "xembsni"];
  # Tests that need an X server or a D-Bus session skip themselves in the
  # sandbox, so the rest still runs.

  meta = {
    description = "XEmbed to StatusNotifierItem tray bridge";
    homepage = "https://github.com/jmylchreest/xembsni";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "xembsni";
    platforms = lib.platforms.linux;
  };
}
