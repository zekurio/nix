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
  nixpkgs.overlays = [overlay];
}
