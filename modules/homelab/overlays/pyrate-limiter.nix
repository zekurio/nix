let
  overlay = _final: previous: {
    pythonPackagesExtensions =
      previous.pythonPackagesExtensions
      ++ [
        (_pythonFinal: pythonPrevious: {
          pyrate-limiter = pythonPrevious.pyrate-limiter.overridePythonAttrs (old: {
            # Asserts multiprocess bucket fill levels within 10% of the limit,
            # which overshoots when the builder is under load. Nixpkgs already
            # skips test_limiter_01 for the same reason:
            # https://github.com/vutran1710/PyrateLimiter/issues/245
            disabledTests = (old.disabledTests or []) ++ ["test_mp_bucket_async"];
          });
        })
      ];
  };
in {
  # Only beets pulls this in, so the overlay stays out of the base and keeps
  # other hosts on the binary cache.
  nixpkgs.overlays = [overlay];
}
