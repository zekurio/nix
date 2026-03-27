{inputs, ...}: {
  # TODO(zekurio): Temporary workaround.
  # Beets from nixpkgs-unstable currently fails to build due to a sphinx/autodocsumm mismatch,
  # so we pin only beets to nixpkgs-stable until unstable packaging is fixed upstream.
  nixpkgs.overlays = [
    (final: _: {
      beets = inputs.nixpkgs-stable.legacyPackages.${final.stdenv.hostPlatform.system}.beets;
    })
  ];
}
