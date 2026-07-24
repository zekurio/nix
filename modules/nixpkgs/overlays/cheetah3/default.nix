let
  overlay = _final: previous: {
    pythonPackagesExtensions =
      previous.pythonPackagesExtensions
      ++ [
        (_pythonFinal: pythonPrevious: {
          cheetah3 = pythonPrevious.cheetah3.overridePythonAttrs (_: {
            pname = "ct3";
          });
        })
      ];
  };
in {
  flake.modules.nixos.base.nixpkgs.overlays = [overlay];
  flake.modules.darwin.base.nixpkgs.overlays = [overlay];
}
