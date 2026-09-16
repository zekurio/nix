let
  # nixos-unstable repl b1b875982b17dabde9b4a37f3e229e74913e6db3 shipped the
  # playwright 1.63.0 update with two breakages that nixos/nixpkgs master has
  # since fixed: a stale playwright-python source hash, and a playwright-webkit
  # build that cannot link libmanette. Both overrides are guarded, so this file
  # goes inert once nixos-unstable advances past that rev; drop it then.
  overlay = _final: previous: let
    lib = previous.lib;
  in {
    pythonPackagesExtensions =
      previous.pythonPackagesExtensions
      ++ [
        (_pythonFinal: pythonPrevious: {
          playwright = pythonPrevious.playwright.overridePythonAttrs (
            old:
              lib.optionalAttrs (old.version == "1.63.0") {
                src = previous.fetchFromGitHub {
                  owner = "microsoft";
                  repo = "playwright-python";
                  tag = "v${old.version}";
                  hash = "sha256-RwIn+0EcHnStjORVFmT7gp4bGjl+qer1FgtI3+aPF2w=";
                };
              }
          );
        })
      ];

    # The guard has to sit inside the override: testing it while the overlay
    # result is built would force playwright-driver mid-fixpoint and recurse.
    playwright-driver = previous.playwright-driver.overrideAttrs (
      old:
        lib.optionalAttrs
        (previous.stdenv.hostPlatform.isLinux
          && !(builtins.elem previous.libmanette (old.passthru.components.webkit.buildInputs or [])))
        {
          # Chromium is what the test suites reaching this driver launch, and
          # the browser linkFarm is a plain symlink farm, so leaving webkit out
          # is cheaper than rebuilding it patched in from this side.
          passthru =
            (old.passthru or {})
            // {
              browsers = old.passthru.browsers.override {withWebkit = false;};
            };
        }
    );
  };
in {
  flake.modules.nixos.base.nixpkgs.overlays = [overlay];
  flake.modules.darwin.base.nixpkgs.overlays = [overlay];
}
