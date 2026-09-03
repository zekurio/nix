let
  overlay = final: previous: {
    # 0.8.2 breaks Steam's override-redirect menus by returning focus to the
    # main window. Remove this pin once upstream issue #468 is fixed.
    xwayland-satellite = previous.xwayland-satellite.overrideAttrs (_finalAttrs: _previousAttrs: let
      version = "0.8.1";
      src = final.fetchFromGitHub {
        owner = "Supreeeme";
        repo = "xwayland-satellite";
        tag = "v${version}";
        hash = "sha256-BUE41HjLIGPjq3U8VXPjf8asH8GaMI7FYdgrIHKFMXA=";
      };
    in {
      inherit version src;
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit src;
        hash = "sha256-16L6gsvze+m7XCJlOA1lsPNELE3D364ef2FTdkh0rVY=";
      };
    });
  };
in {
  flake.modules.nixos.lilith.nixpkgs.overlays = [overlay];
}
