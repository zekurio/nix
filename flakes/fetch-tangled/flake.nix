{
  # Stands in for tangled.org/isabelroses.com/fetch-tangled, which was deleted
  # once its fetcher moved into nixpkgs. Tangled's nixos-26.05 pin predates
  # that, so the overlay takes the fetcher from the nixpkgs this follows.
  # modules/homelab/services/knot/default.nix warns when Tangled moves on.
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: {
    overlays.default = final: _: {
      fetchFromTangled = final.callPackage "${nixpkgs}/pkgs/build-support/fetchtangled" {};
    };
  };
}
