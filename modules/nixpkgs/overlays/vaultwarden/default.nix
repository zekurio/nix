# Temporary: the pinned nixos-unstable still ships vaultwarden 1.36.0, while
# 1.37.0 (2026-07-24) carries the security fixes. That release also bumps the
# bundled web vault to 2026.6.4, so server and web vault have to move together.
# nixos-unstable-small already has both (nixpkgs c705f56a), so take the package
# from there rather than re-deriving hashes locally: that keeps the server and
# web vault at the version pair upstream ships, and avoids back-porting a
# webvault expression that now wants npmDepsFetcherVersion = 3.
#
# Neither output is in cache.nixos.org yet (checked 2026-07-25), so the first
# rebuild compiles vaultwarden from source and builds the web vault with npm.
#
# Drop this file and the nixpkgs-small input once nixos-unstable ships >= 1.37.0.
{inputs, ...}: let
  overlay = _final: previous: {
    inherit (inputs.nixpkgs-small.legacyPackages.${previous.system}) vaultwarden;
  };
in {
  # Only NixOS hosts run vaultwarden; the darwin base is deliberately untouched.
  flake.modules.nixos.base.nixpkgs.overlays = [overlay];
}
